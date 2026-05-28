#!/bin/bash
set -eo pipefail
cd /opt/7_filter_ea_results

if [ $# -lt 2 ]; then
	printf "Usage: %s <dir1> <dir2> ...\n" "$0"
	exit 1
fi

# tools dictionaries
declare -A tools=(
	[gprof]="gprofiler"
	[panther]="panther"
	[gsea]="gsea"
)
declare -A tools_dirs
declare -A found_fields_files
declare -A found_annots_files
active_tools=()

# start report file
> report

# assign input directories to tools
for dir in "$@"; do
	matched=false
	for key in "${!tools[@]}"; do
		if [[ "$dir" == *"${tools[$key]}"* ]]; then
			tools_dirs[$key]="$dir" 
			matched=true
			break
		fi
	done
	[[ "$matched" == false ]] && echo "Warning: No match found for $dir"
done

field_file="enrichment_fields.tsv"

#function to find annotations results file since it can  vart between tools and doesnt follow a rule when it comes fo GSEA classic runs
get_annot_file() {
	local dir="$1"
	local matches
	# Priority 1: Exact
	matches=$(find "$dir" -maxdepth 2 -name "enriched_terms_annotations.tsv")
	# Priority 2: Positive
	[[ -z "$matches" ]] && matches=$(find "$dir" -maxdepth 2 -name "enriched_terms_annotations_pos.tsv")
	# Priority 3: Fallback (all non-neg)
	[[ -z "$matches" ]] && matches=$(find "$dir" -maxdepth 2 -name "enriched_terms_annotations*.tsv" ! -name "*_neg.tsv")
	
	echo "$matches"
}

# loop multiple tools dirs and find fields and annots files (1 and 2)
for key in "${!tools_dirs[@]}"; do
	dir="${tools_dirs[$key]}"
	# find fields enriched
	file_1=$(find "$dir" -maxdepth 2 -name "enrichment_fields.tsv" -print -quit)
	# find one (or multiple) enriched annotations files (priority *_pos; then any phenotypes from gsea Classic)
	all_files_2=$(get_annot_file "$dir")
	if [[ -z "$file_1" ]]; then
		echo "❌ Error: Required file '$file_1' not found for $key"
		exit 1
	fi

	if [[ -z "$all_files_2" ]]; then
		echo "❌ Error: Required files 'enriched_terms_annotations*.tsv' not found for $key"
		exit 1
	fi

	# every annotation file found for this tool
	for file_2 in $all_files_2; do
		# create unique identifier (e.g., gsea_control; with 'control' being the phenotype)
		suffix=$(basename "$file_2" .tsv | sed 's/enriched_terms_annotations//;s/^_//')
		unique_tool_id="${key}"
		[[ ! -z "$suffix" ]] && unique_tool_id="${key}_${suffix}"
		# register in found files arrays
		found_fields_files[$unique_tool_id]="$file_1"
		found_annots_files[$unique_tool_id]="$file_2"
		active_tools+=("$unique_tool_id")
	done
	printf "Enrichment results of %s processed with similarity analysis: %s\n" "$tools_dirs[$key]" "$file_1" >> report
done

printf "\n" >> report

#check if the tool is in found_fields_files before trying to awk it
# "${found_fields_files[tool]}" must match declared key [tool] in 'tools' array
# gprofiler name column ($2) and source column ($4)
for key in "${!found_fields_files[@]}"; do
	f_fields="${found_fields_files[$key]}"
	f_annot="${found_annots_files[$key]}"
	base_key="${key%%_*}"

	if [[ "$base_key" == "gsea" ]]; then
		phenotype="${key#*_}"
		awk -F"\t" -v pk="$phenotype" 'BEGIN {OFS="\t"} (/GOMF|GOBP|GOCC|REACTOME/) && $3 == pk {
			term = $1; prefix = substr(term, 1, index(term, "_") - 1); rest = substr(term, index(term, "_") + 1);
			gsub(/_/, " ", rest); gsub(/GOBP/, "GO_BP", prefix); gsub(/GOMF/, "GO_MF", prefix); gsub(/GOCC/, "GO_CC", prefix); gsub(/REACTOME/, "REAC", prefix);
			print toupper(rest), toupper(prefix) }' "$f_fields" > "${key}_terms"
		awk -F"\t" 'BEGIN {OFS="\t"} (/GOMF|GOBP|GOCC|REACTOME/) {
			term = $1; prefix = substr(term, 1, index(term, "_") - 1); rest = substr(term, index(term, "_") + 1);
			gsub(/_/, " ", rest); gsub(/GOBP/, "GO_BP", prefix); gsub(/GOMF/, "GO_MF", prefix); gsub(/GOCC/, "GO_CC", prefix); gsub(/REACTOME/, "REAC", prefix);
			print toupper(rest), toupper(prefix), $6 }' "$f_annot" > "${key}_genes"
	elif [[ "$base_key" == "gprof" ]]; then
		awk -F"\t" 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ { print toupper($2), toupper($4) }' "$f_fields" > "${key}_terms"
		awk -F"\t" 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ { print toupper($2), toupper($3), $6 }' "$f_annot" > "${key}_genes"
	else
		awk -F"\t" 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ { print toupper($2), toupper($3) }' "$f_fields" > "${key}_terms"
		awk -F"\t" 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ { print toupper($2), toupper($3), $6 }' "$f_annot" > "${key}_genes"
	fi
done

# report generation
declare -A totals
for tool in "${active_tools[@]}"; do
	totals[$tool]=$(wc -l < "${tool}_genes")
	echo "Total enriched terms by $tool: ${totals[$tool]}" >> report
done

printf "\n" >> report

# dynamically calculate pairwise pntersections and jaccard
num_active=${#active_tools[@]}
for (( i=0; i<num_active; i++ )); do
	for (( j=i+1; j<num_active; j++ )); do
		t1="${active_tools[$i]}"; t2="${active_tools[$j]}"
		base1="${t1%%_*}"
		base2="${t2%%_*}"
		# SKIP if both are the same tool (case of gsea)
		if [[ "$base1" == "$base2" ]]; then
			continue
		fi
		out_common="common_${t1}_${t2}_terms.txt"
		comm -12 <(sort "${t1}_terms") <(sort "${t2}_terms") > "$out_common"
		sim=$(wc -l < "$out_common")
		echo "Number of similar terms between $t1 and $t2: ${sim}" >> report
		denom=$(( totals[$t1] + totals[$t2] - sim ))
		jacc=$( [ "$denom" -gt 0 ] && echo "scale=6; $sim / $denom" | bc || echo "0.000000" )
		echo "Jaccard similarity between $t1 and $t2: ${jacc}" >> report
		printf "\n" >> report
	done
done

# find unique tools to compare between them (excluing cases were GSEA could have two keys)
declare -A unique_tools
for tool in "${active_tools[@]}"; do
	base="${tool%%_*}"
	if [[ -z "${unique_tools[$base]}" ]]; then
		unique_tools[$base]="$tool"
	fi
done

# cross ALL active unique streams
num_unique=${#unique_tools[@]}
if [ "$num_unique" -ge 3 ]; then
	gsea_keys=()
	other_tools=()

	for tool in "${active_tools[@]}"; do
		if [[ "$tool" == gsea* ]]; then
			gsea_keys+=("$tool")
		else
			other_tools+=("$tool")
		fi
	done

	# intersect each GSEA key separately with the other tools
	for gsea_key in "${gsea_keys[@]}"; do
		phenotype="${gsea_key#*_}"
		current_files=()
		current_tools=()
		# add other tools files
		for t in "${other_tools[@]}"; do 
			current_files+=("${t}_terms")
			current_tools+=("${t}")
		done
		# add gsea file
		current_tools+=("${gsea_key}")
		current_files+=("${gsea_key}_terms")
		n_tools=${#current_files[@]}
		out_file="common_gprof_panther_pos_${gsea_key}_terms.txt"
		cat "${current_files[@]}" | sort | uniq -c | \
		awk -v n="$n_tools" '
			$1 == n {
				$1=""
				sub(/^[ \t]+/, "")

				source=$NF
				$NF=""

				sub(/[ \t]+$/, "")
				print $0 "\t" source
			}' > "$out_file"
		total_to_all=$(wc -l < "$out_file")
		echo "Number of similar terms between all tools (with '$gsea_key'): $total_to_all" >> report
		echo "Generated $out_file by intersecting: ${current_tools[*]}" >> report
	done
fi

echo -e "\n=== ENRICHMENT ANALYSIS INTERSECTION REPORT ==="
cat report

printf "\nFinding similar genes from common enriched terms between tools...\n"
# interact over common results files and get common genes
for common_file in common_*_terms.txt; do
	[ -s "$common_file" ] || continue
	output_genes_file="${common_file%_terms.txt}_genes.txt"
	> "$output_genes_file"

	# dynamically identify tools involved
	tools_involved=()
	for tool_key in "${active_tools[@]}"; do
		if [[ "$common_file" == *"$tool_key"* ]]; then
			tools_involved+=("$tool_key")
		fi
	done

	while IFS=$'\t' read -r term source; do
		# collect gene lists from each tool
		all_genes_lists=()
		for tool in "${tools_involved[@]}"; do
			genes_string=$(awk -F"\t" -v t="$term" -v s="$source" \
				'$1 == t && $2 == s {print $3}' "${tool}_genes")
			if [[ -n "$genes_string" ]]; then
				cleaned=$(echo "$genes_string" | tr ',; ' '\n' | sed '/^$/d' | sort -u)
				all_genes_lists+=("$cleaned")
			fi
		done

		if [ "${#all_genes_lists[@]}" -eq "${#tools_involved[@]}" ]; then
			# pipe all gene lists into uniq -c to find common items
			common_genes=$(
				printf "%s\n" "${all_genes_lists[@]}" |
				sort |
				uniq -c |
				awk -v n="${#tools_involved[@]}" '$1 >= n {print $2}' |
				paste -sd "," -
			)

			echo -e "${term}\t${source}\t${common_genes:-None}" >> "$output_genes_file"
		fi
	done < "$common_file"
	echo "Generated common genes file: $output_genes_file"
done

rm *terms*
rm *genes
