#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <input_ids_map_file> <gprofiler_annotations_file>\n" "$0"
	exit 1
fi

input_file="$1" # gene ids col1, uniprotkbs col2, gene symbols col3 and names col4
gmt_file="$2"
results_file="short_results.csv"

if [ ! -f "$gmt_file" ]; then
	printf "Error: GMT file not found.\n"
	exit 1
fi

combined_results="terms_annotations_results.csv"
printf "TermID,Name,Source,Ratio(%%),ListCount,Genes_in_list,TermCount,Genes_in_term\n" > "$combined_results"

declare -A ID_TO_SYMBOL ID_TO_NAME
while IFS=$'\t' read -r gene_id _ symbol fullname; do
	[[ -n "$gene_id" && -n "$symbol" ]] && ID_TO_SYMBOL["$gene_id"]="$symbol"
	[[ -n "$gene_id" && -n "$fullname" ]] && ID_TO_NAME["$gene_id"]="$fullname"
done < <(tail -n +2 "$input_file")

total_terms=$(($(wc -l < "$results_file") - 1))
term_index=0

tail -n +2 "$results_file" | while IFS=',' read -r term_id name col3 source; do
	((term_index++))
	printf "Processing enriched term annotations %s/%s: $term_id ($name)\n" "$term_index" "$total_terms"
	if [[ "$source" == "KEGG" || "$source" == "TF" ]]; then
		printf "WARNING: Skipping %s — source $source omitted due to licensing issues.\n" "$term_id"
		continue
	fi

	output_dir="results/${source}/terms_annotations"
	mkdir -p "$output_dir"

	matched_lines=$(grep -P "^$term_id\t" "$gmt_file" | sort -u)
	if [ -z "$matched_lines" ]; then
		continue
	fi

	sanitized_name=$(printf "%s" "$name" | sed 's/,/ /g')
	term_dir="${output_dir}/${term_id}_${sanitized_name}"
	mkdir -p "$term_dir"

	echo "$matched_lines" | cut -f3- | tr '\t' '\n' | sort -u > "${term_dir}/genes_in_term"
	total_genes=$(wc -l < "${term_dir}/genes_in_term")

	matched_file="${term_dir}/genes_in_list"
	printf "GeneID\tGeneSymbol\tOfficialFullName\n" > "$matched_file"

	#matched_ids=()
	matched_symbols=()

	while read -r gene_id; do
		symbol="${ID_TO_SYMBOL[$gene_id]}"
		fullname="${ID_TO_NAME[$gene_id]}"
		if [ -n "$symbol" ]; then
			if grep -qxF "$symbol" "${term_dir}/genes_in_term"; then
				printf "%s\t%s\t%s\n" "$gene_id" "$symbol" "$fullname" >> "$matched_file"
				#matched_ids+=("$gene_id")
				matched_symbols+=("$symbol")
			fi
		fi
	done < <(printf "%s\n" "${!ID_TO_SYMBOL[@]}")

	matched_count=${#matched_symbols[@]}
	ratio=$(awk -v m="$matched_count" -v t="$total_genes" 'BEGIN { if (t > 0) printf "%.2f", (m / t)*100; else print 0 }')
	#joined_ids=$(IFS=" "; echo "${matched_ids[*]}")
	joined_symbols=$(IFS=" "; echo "${matched_symbols[*]}")
	term_genes=$(paste -sd' ' "${term_dir}/genes_in_term")

	printf "%s,%s,%s,%s,%d,%s,%d,%s\n" \
		"$term_id" "$sanitized_name" "$source" "$ratio" "$matched_count" "$joined_symbols" "$total_genes" "$term_genes" >> "$combined_results"
done