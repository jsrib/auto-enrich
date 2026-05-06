#!/bin/bash

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

printf "TermID\tName\tSource\tCoverage\tIntersectionSize\tGenes_in_intersection\tTermSize\tGenes_in_term\n" > "$output_file"

# read the input gene id mapping into associative arrays for quick lookup
declare -A ID_TO_SYMBOL
while IFS=$'\t' read -r gene_id uniprot symbol; do
	[[ -n "$gene_id" && -n "$symbol" ]] && ID_TO_SYMBOL["$gene_id"]="$symbol"
	[[ -n "$gene_id" && -n "$uniprot" ]] && ID_TO_SYMBOL["$gene_id"]="$uniprot"
done < "${map_file}"

total_terms=$(($(wc -l < "${ids_file}") - 1))
term_index=0

# process each enriched term, extract genes in term and in intersection, and save annotations
tail -n +2 "$fields_file" | while IFS='\t' read -r term_id name _ source _ _ _ queryS coverage interS termS _ _ _ _ _; do
	((term_index++))
	printf "Processing enriched term %s/%s: %s %s (%s)\n" "$term_index" "$total_terms" "$term_id" "$name" "$source"
	if [[ "$source" == "KEGG" || "$source" == "TF" ]]; then
		printf "WARNING: Skipping %s — source $source omitted due to licensing issues.\n" "$term_id"
		continue
	fi

	source_dir="${save_dir}/${source}/annotations"
	mkdir -p "$source_dir"

	term_line=$(grep -P "^$term_id\t" "$gmt_file" | sort -u)
	if [ -z "$term_line" ]; then
		continue
	fi

	# sanitize name and term_id for filesystem
	sanitized_name=$(printf "%s" "$name" | sed 's/,/ /g')
	sanitized_termid=$(printf "%s" "$term_id" | sed 's/:/_/g')
	term_dir="${source_dir}/${sanitized_termid}_${sanitized_name}"
	mkdir -p "$term_dir"

	# extract genes in term
	echo "$term_line" | cut -f3- | tr '\t' '\n' > "${term_dir}/genes_in_term"
	term_size=$(wc -l < "${term_dir}/genes_in_term")
	genes_in_term=$(paste -sd' ' "${term_dir}/genes_in_term")

	intersection_file="${term_dir}/genes_in_intersection"
	printf "GeneID\tUniprots\tGeneSymbol\n" > "$intersection_file"

	genes_in_intersection=()
	# check which genes from the input list are in the term
	while read -r gene_id; do
		symbol="${ID_TO_SYMBOL[$gene_id]}"
		uniprots="${ID_TO_SYMBOL[$gene_id]}"
		if [ -n "$symbol" ]; then
			if grep -qxF "$symbol" "${term_dir}/genes_in_term"; then
				printf "%s\t%s\t%s\n" "$gene_id" "$uniprots" "$symbol" >> "$intersection_file"
				genes_in_intersection+=("$symbol")
			fi
		fi
	done < <(printf "%s\n" "${!ID_TO_SYMBOL[@]}")

	intersection_size=${#genes_in_intersection[@]}
	# coverage is the ratio of term genes that are in the intersection
	coverage=$(awk -v m="$intersection_size" -v t="$term_size" 'BEGIN { if (t > 0) printf "%.2f", (m / t); else print 0 }')
	#joined_ids=$(IFS=" "; echo "${matched_ids[*]}")
	genes_in_intersection_str=$(IFS=" "; echo "${genes_in_intersection[*]}")

	printf "%s,%s,%s,%s,%d,%s,%d,%s\n" \
		"$term_id" "$name" "$source" "$coverage" "$intersection_size" "$genes_in_intersection_str" "$term_size" "$genes_in_term" >> "$output_file"
done