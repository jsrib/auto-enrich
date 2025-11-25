#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <results_dir> <gmx_file>\n" "$0"
	exit 1
fi

input_dir="$1"
gmx_file="$2"

if [[ ! -d "$input_dir" ]]; then
	printf "Error: '$input_dir' is not a valid directory."
	exit 1
fi

if [[ ! -f "$gmx_file" ]]; then
	printf "\nError: Gene Set file '%s' does not exist.\n" "$gmx_file"
	exit 1
fi

analysis_dir=$(find "${input_dir}" -mindepth 1 -maxdepth 1 -type d)
results_file="${analysis_dir}/short_results.csv"
genes_list="${analysis_dir}/raw_GSEA_output/edb/gene_sets.gmt"
terms_dir="${analysis_dir}/terms_annotations"
output_file="${analysis_dir}/terms_annotations_results.csv"
printf "Name,Source,Phenotype,Ratio(%%),ListCount,Genes_in_list,TermCount,Genes_in_term\n" > "$output_file"

# read results
tail -n +2 "$results_file" | while IFS=',' read -r name phenotype nes fdr ; do
	line_term=$(grep -P "^${name}\t" "$gmx_file")
	# get source directly from GSEA term page
	if [[ -n "$line_term" ]]; then
		genes=$(printf "%s\n" "$line_term" | cut -f3-)
		url=$(printf "%s\n" "$line_term" | cut -f2)
		page=$(curl -s "$url")
		source=$(printf "%s\n" "$page" | grep -A1 "Source publication" | tail -n1 | sed 's/<[^>]*>//g' | awk -F'&' '{print $1}' | xargs)
		if [[ -z "$source" ]]; then
			source=$(printf "%s\n" "$page" | grep -A1 "Contributed by" | tail -n1 | sed 's/<[^>]*>//g' | awk -F'&' '{print $1}' | xargs)
		fi

		if [[ $source == Pubmed* ]]; then
			source="Pubmed"
		fi
		term_dir="${analysis_dir}/${source}/terms_annotations/${name}"
		mkdir -p "$term_dir"

		printf "%s\n" "$genes" | tr '\t' '\n' > "${term_dir}/genes_in_term"
	fi

	line_list=$(grep -P "^${name}\t" "$genes_list")
	if [[ -n "$line_list" ]]; then
		genes=$(printf "%s\n" "$line_list" | cut -f3-)
		printf "%s\n" "$genes" | tr '\t' '\n' > "${term_dir}/genes_in_list"
	fi

	genes_in_list=""
	[[ -f "${term_dir}/genes_in_list" ]] && genes_in_list=$(< "${term_dir}/genes_in_list")

	genes_in_term=""
	[[ -f "${term_dir}/genes_in_term" ]] && genes_in_term=$(< "${term_dir}/genes_in_term")

	count_list=$(printf "%s\n" "$genes_in_list" | grep -c . || echo 0)
	count_term=$(printf "%s\n" "$genes_in_term" | grep -c . || echo 0)

	ratio=0
	if [[ $count_term -ne 0 ]]; then
		ratio=$(awk "BEGIN { printf \"%.4f\", ($count_list / $count_term)*100 }")
	fi

	genes_list_str=$(printf "%s" "$genes_in_list" | paste -sd " " -)
	genes_term_str=$(printf "%s" "$genes_in_term" | paste -sd " " -)

	printf "%s,%s,%s,%s,%s,%s,%s,%s\n" \
		"$name" "$source" "$phenotype" "$ratio" \
		"$count_list" "$genes_list_str" \
		"$count_term" "$genes_term_str" >> "$output_file"
done
