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

# assign input directories to tools
for dir in "$@"; do
	dir_base=$(basename "$dir")
	matched=false
	for key in "${!tools[@]}"; do
		if [[ "$dir" == *"${tools[$key]}"* ]]; then
			unique_key="${key}_${dir_base}"
			tools_dirs[$unique_key]="$dir"
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
	local tool_key="$2"
	echo "$dir $tool_key"
	if [[ "$tool_key" == "panther" ]]; then
		find "$dir" -maxdepth 2 -name "enriched_terms_annotations_pos.tsv" -print -quit
	elif [[ "$tool_key" == "gsea" ]]; then
		find "$dir" -maxdepth 2 -name "enriched_terms_annotations_pos.tsv" -print -quit || \
		find "$dir" -maxdepth 2 -name "enriched_terms_annotations*.tsv" -not -name "*_neg.tsv" -print -quit
	else
		find "$dir" -maxdepth 2 -name "enriched_terms_annotations.tsv" -print -quit
	fi
}

# safely locate files for passed tools
echo "Checking for $field_file in identified directories..."
for key in "${!tools_dirs[@]}"; do
	dir="${tools_dirs[$key]}"
	file_1=$(find "$dir" -maxdepth 2 -name "enrichment_fields.tsv" -print -quit)
	file_2=$(get_annot_file "$dir" "$key")
	echo "  file_1 (enrichment_fields.tsv) found: ${file_1:-NOT FOUND}"
	echo "  file_2 (annot file) result: ${file_2:-NOT FOUND}"
	if [[ -n "$file_1" && -n "$file_2" ]]; then
		found_fields_files[$key]="$file_1"
		found_annots_files[$key]="$file_2"
	else
		echo "❌ Error: Required files not found for $key"
		exit 1
	fi
done

#check if the tool is in found_fields_files before trying to awk it
# "${found_fields_files[tool]}" must match declared key [tool] in 'tools' array
# gprofiler name column ($2) and source column ($4)
for key in "${!found_fields_files[@]}"; do
	f_fields="${found_fields_files[$key]}"
	f_annot="${found_annots_files[$key]}"
	base_key="${key%%_*}"

	if [[ "$base_key" == "gsea" ]]; then
		phenotypes=($(awk -F"\t" '{print $3}' "$f_fields" | grep -v "Phenotype" | sort -u))
		for pk in "${phenotypes[@]}"; do
			t_file="gsea_${pk}_${key}_terms"
			g_file="gsea_${pk}_${key}_genes"
			awk -F"\t" -v pk="$pk" 'BEGIN {OFS="\t"} (/GOMF|GOBP|GOCC|REACTOME/) && $3 == pk {
				term = $1; prefix = substr(term, 1, index(term, "_") - 1); rest = substr(term, index(term, "_") + 1);
				gsub(/_/, " ", rest); gsub(/GOBP/, "GO_BP", prefix); gsub(/GOMF/, "GO_MF", prefix); gsub(/GOCC/, "GO_CC", prefix); gsub(/REACTOME/, "REAC", prefix);
				print toupper(rest), toupper(prefix) }' "$f_fields" > "$t_file"
			awk -F"\t" -v pk="$pk" 'BEGIN {OFS="\t"} (/GOMF|GOBP|GOCC|REACTOME/) && $3 == pk {
				term = $1; prefix = substr(term, 1, index(term, "_") - 1); rest = substr(term, index(term, "_") + 1);
				gsub(/_/, " ", rest); gsub(/GOBP/, "GO_BP", prefix); gsub(/GOMF/, "GO_MF", prefix); gsub(/GOCC/, "GO_CC", prefix); gsub(/REACTOME/, "REAC", prefix);
				print toupper(rest), toupper(prefix), $7 }' "$f_annot" > "$g_file"
			active_tools+=("gsea_${pk}_${key}")
		done
	else
		awk -F"\t" 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ { print toupper($2), toupper($4) }' "$f_fields" > "${key}_terms"
		awk -F"\t" 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ {print toupper($2), toupper($3), $6}' "$f_annot" > "${key}_genes"
		active_tools+=("$key")
	fi
done

# report generation
> report
declare -A totals
for t in "${active_tools[@]}"; do
	totals[$t]=$(wc -l < "${t}_terms")
	echo "Total terms for $t: ${totals[$t]}" >> report
done

# dynamically calculate pairwise pntersections and jaccard
num_active=${#active_tools[@]}
for (( i=0; i<num_active; i++ )); do
	for (( j=i+1; j<num_active; j++ )); do
		t1="${active_tools[$i]}"; t2="${active_tools[$j]}"
		out_common="common_terms_${t1}_${t2}.txt"
		comm -12 <(sort "${t1}_terms") <(sort "${t2}_terms") > "$out_common"
		sim=$(wc -l < "$out_common")
		denom=$(( totals[$t1] + totals[$t2] - sim ))
		jacc=$( [ "$denom" -gt 0 ] && echo "scale=6; $sim / $denom" | bc || echo "0.000000" )
		echo "Jaccard similarity between $t1 and $t2: ${jacc}" >> report
	done
done

# cross ALL active streams for exact common terms dynamically
cat_files=""
for tool in "${active_tools[@]}"; do cat_files="$cat_files ${tool}_terms"; done

# check that a term appeared in ALL tools results
common_to_all="common_terms_to_all.txt"
for tool in "${active_tools[@]}"; do cat_files="$cat_files ${tool}_terms"; done

if [ "$num_active" -ge 3 ]; then
	cat $cat_files | sort | uniq -c | awk -v n="$num_active" '$1 == n { $1=""; sub(/^ /, ""); print }' > "$common_to_all"
	sim_all=$(wc -l < "$common_to_all")
	echo "Number of similar terms across all $num_active tools: ${sim_all}" >> report
fi

echo -e "\n=== ENRICHMENT ANALYSIS INTERSECTION REPORT ==="
cat report


# now get genes in common between intersected terms
gprof_annot="${found_annots_files[gprof]}"
panther_annot="${found_annots_files[panther]}"
gsea_annot="${found_annots_files[gsea]}"
# optimized mapping files [TERM \t SOURCE \t GENES] for lookup
# gProfiler (Term: $2, Source: $3, Genes: $6)
if [[ -n "$gprof_annot" ]]; then
	awk -F"\t" 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ {print toupper($2), toupper($3), $6}' "$gprof_annot" > gprof_genes
fi

# Panther (Term: $2, Source: $3, Genes: $6)
if [[ -n "$panther_annot" ]]; then
	awk -F"\t" 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ {print toupper($2), toupper($3), $6}' "$panther_annot" > panther_genes
fi

# interact over common results files and get common genes
for common_file in common_terms_*_*.txt; do
	[ -s "$common_file" ] || continue
	output_genes_file="${common_file%.txt}_genes.txt" do
	
	tools_involved=()
	if [[ "$common_file" == *"all"* ]]; then
		tools_involved=(gprof panther gsea)
	else
		[[ "$common_file" == *"gprof"* ]] && tools_involved+=(gprof)
		[[ "$common_file" == *"panther"* ]] && tools_involved+=(panther)
		[[ "$common_file" == *"gsea"* ]] && tools_involved+=(gsea)
	fi

	output_genes_file="${common_file%.txt}_genes.txt"
	> "$output_genes_file"

	while IFS=$'\t' read -r term source; do
		gene_streams=()
		for tool in "${tools_involved[@]}"; do
			# get genes column
			genes_string=$(awk -F"\t" -v t="$term" -v s="$source" '$1 == t && $2 == s {print $3}' "${tool}_genes")
			if [[ -n "$genes_string" ]]; then
				gene_streams+=("<(echo \"$genes_string\" | tr '[,; ]' '\n' | sort -u)")
			fi
		done

		# only proceed if gene data with involved tools
		if [ "${#gene_streams[@]}" -eq "${#tools_involved[@]}" ]; then
			if [ "${#tools_involved[@]}" -eq 2 ]; then
				common_genes=$(eval "comm -12 ${gene_streams[0]} ${gene_streams[1]}" | paste -sd "," -)
			else
				common_genes=$(eval "comm -12 ${gene_streams[0]} ${gene_streams[1]} | comm -12 - ${gene_streams[2]}" | paste -sd "," -)
			fi

			if [[ -n "$common_genes" ]]; then
				echo -e "${term}\t${source}\t${common_genes}" >> "$output_genes_file"
			else
				echo -e "${term}\t${source}\tNone" >> "$output_genes_file"
			fi
		fi
	done < "$common_file"
	echo "Generated common genes file: $output_genes_file"
done
mv *_genes /data