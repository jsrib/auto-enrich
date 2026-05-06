#!/bin/bash
# set -euo pipefail

if [ $# -ne 4 ]; then
	printf "Usage: %s <input_ids_map_file> <gprof_gene_sets> <results_file> <output_file>\n" "$0"
	exit 1
fi

map_file="$1" # input file with gene id mapping (geneid, uniprot, symbol)
gmt_file="$2"
fields_file="$3"
save_dir="$4"

output_file="$save_dir/enriched_terms_annotations.tsv"

if [ ! -f "$gmt_file" ]; then
	printf "❌ [MODULE 3] Error: gProfiler gene sets file not found.\n"
	exit 1
fi

if [ ! -f "$fields_file" ]; then
	printf "❌ [MODULE 3] Error: Enriched fields file '%s' not found.\n" "$fields_file"
	exit 1
fi

printf "TermID\tName\tSource\tCoverage\tIntersectionSize\tGenes_in_intersection\tTermSize\tGenes_in_term\n" > "$output_file"

declare -A GMT_MAP
printf "Indexing GMT file for fast lookup...\n"
while IFS=$'\t' read -r term_id desc genes; do
	GMT_MAP["$term_id"]="${genes//"$IFS"/ }" # Store genes space-separated
done < <(cut -f1,2,3- "$gmt_file")

# loop over enriched terms and get genes in term and intersection
tail -n +2 "$fields_file" | while IFS=$'\t' read -r term_id name _ source _ _ _ queryS coverage interS termS _ _ _ _ _; do
	((term_index++))
	
	# simple check to skip sources
	if [[ "$source" == "KEGG" || "$source" == "TF" ]]; then
		printf "WARNING: Skipping %s — source %s omitted.\n" "$term_id" "$source"
		continue
	fi

	# instant lookup from memory
	genes_in_term_str="${GMT_MAP[$term_id]}"
	[[ -z "$genes_in_term_str" ]] && continue

	# FAST SANITIZATION: Use Bash parameter expansion instead of 'sed'
	# s/[,/]/ /g equivalent:
	temp_name="${name//,/ }"
	sanitized_name="${temp_name//\// }"
	sanitized_termid="${term_id//:/_}"
	
	term_dir="${save_dir}/${source}/annotations/${sanitized_termid}_${sanitized_name}"
	mkdir -p "$term_dir"

	# GENERATE GENES_IN_TERM FILE - Convert space-separated string back to newline-separated file
	printf "%b" "${genes_in_term_str// /\n}" > "${term_dir}/genes_in_term"
	term_size=$(echo "$genes_in_term_str" | wc -w)

	# calculate Intersection
	intersection_file="${term_dir}/genes_in_intersection"
	printf "GeneID\tUniprots\tGeneSymbol\n" > "$intersection_file"
	
	# load term genes into a local associative array for O(1) lookup
	declare -A term_lookup=()
	for g in $genes_in_term_str; do term_lookup["$g"]=1; done

	genes_in_intersection=()
	for gene_id in "${input_gene_ids[@]}"; do
		symbol="${ID_TO_SYMBOL[$gene_id]}"
		if [[ -n "$symbol" && ${term_lookup["$symbol"]+_} ]]; then
			printf "%s\t%s\t%s\n" "$gene_id" "${ID_TO_UNIPROT[$gene_id]:-NA}" "$symbol" >> "$intersection_file"
			genes_in_intersection+=("$symbol")
		fi
	done

	# final metrics
	inter_size=${#genes_in_intersection[@]}
	calc_coverage=$(awk -v m="$inter_size" -v t="$term_size" 'BEGIN { printf "%.4f", (t>0 ? m/t : 0) }')
	inter_str="${genes_in_intersection[*]}"

	printf "%s\t%s\t%s\t%s\t%d\t%s\t%d\t%s\n" \
		"$term_id" "$name" "$source" "$calc_coverage" "$inter_size" \
		"$inter_str" "$term_size" "$genes_in_term_str" >> "$output_file"

	unset term_lookup
done


# # read the input gene id mapping into associative arrays for quick lookup
# declare -A ID_TO_SYMBOL
# declare -A ID_TO_UNIPROT

# while IFS=$'\t' read -r gene_id uniprot symbol || [[ -n "$gene_id" ]]; do
# 	[[ "$gene_id" == "GeneID" ]] && continue
# 	[[ -z "$gene_id" ]] && continue

# 	ID_TO_SYMBOL["$gene_id"]="${symbol:-NA}"
# 	ID_TO_UNIPROT["$gene_id"]="${uniprot:-NA}"
# done < "${map_file}"

# total_terms=$(($(wc -l < "${fields_file}") - 1))
# term_index=0

# # Pre-calculate the input gene list for the intersection check
# # This avoids running printf/process substitution inside the loop
# input_gene_ids=("${!ID_TO_SYMBOL[@]}")

# tail -n +2 "$fields_file" | while IFS=$'\t' read -r term_id name _ source _ _ _ queryS coverage interS termS _ _ _ _ _; do
# 	((term_index++))
# 	printf "Processing enriched term %s/%s: %s %s (%s)\n" "$term_index" "$total_terms" "$term_id" "$name" "$source"
	
# 	if [[ "$source" == "KEGG" || "$source" == "TF" ]]; then
# 		printf "WARNING: Skipping %s — source %s omitted.\n" "$term_id" "$source"
# 		continue
# 	fi

# 	# extract GMT line
# 	term_line=$(grep -P "^$term_id\t" "$gmt_file" | head -n 1)
# 	[[ -z "$term_line" ]] && continue

# 	#organize directories
# 	sanitized_name=$(echo "$name" | sed 's/[,/]/ /g')
# 	sanitized_termid=$(echo "$term_id" | sed 's/:/_/g')
# 	term_dir="${save_dir}/${source}/annotations/${sanitized_termid}_${sanitized_name}"
# 	mkdir -p "$term_dir"

# 	# 1. Get genes from GMT and store in an associative array for instant lookup
# 	# Skip first two columns (ID and Description)
# 	declare -A current_term_genes=()
# 	genes_in_term_str=""
	
# 	# Process GMT line into array and formatted string
# 	IFS=$'\t' read -r -a elements <<< "$term_line"
# 	for ((i=2; i<${#elements[@]}; i++)); do
# 		gene="${elements[$i]}"
# 		[[ -z "$gene" ]] && continue
# 		current_term_genes["$gene"]=1
# 		genes_in_term_str+="$gene "
# 	done
# 	term_size=${#current_term_genes[@]}

# 	# 2. Calculate Intersection
# 	intersection_file="${term_dir}/genes_in_intersection"
# 	printf "GeneID\tUniprots\tGeneSymbol\n" > "$intersection_file"

# 	genes_in_intersection=()
# 	for gene_id in "${input_gene_ids[@]}"; do
# 		symbol="${ID_TO_SYMBOL[$gene_id]}"
# 		uniprots="${ID_TO_UNIPROT[$gene_id]:-NA}" # Use the correct array here
		
# 		# Check if the SYMBOL exists in the GMT term array
# 		if [[ -n "$symbol" && ${current_term_genes[$symbol]+_} ]]; then
# 			printf "%s\t%s\t%s\n" "$gene_id" "$uniprots" "$symbol" >> "$intersection_file"
# 			genes_in_intersection+=("$symbol")
# 		fi
# 	done

# 	# 3. Final metrics
# 	intersection_size=${#genes_in_intersection[@]}
# 	coverage=$(awk -v m="$intersection_size" -v t="$term_size" 'BEGIN { printf "%.4f", (t>0 ? m/t : 0) }')
# 	genes_in_intersection_str="${genes_in_intersection[*]}"

# 	# Save summary using Tabs to prevent CSV corruption
# 	printf "%s\t%s\t%s\t%s\t%d\t%s\t%d\t%s\n" \
# 		"$term_id" "$name" "$source" "$coverage" "$intersection_size" \
# 		"$genes_in_intersection_str" "$term_size" "$genes_in_term_str" >> "$output_file"
	
# 	# Clean up array for next iteration
# 	unset current_term_genes
# done