#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <results_directory> <max_n_occurences>\n" "$0"
	exit 1
fi

input_dir="$1"
cutoff="$2"

if [[ ! -d "$input_dir" ]]; then
	printf "\nError: %s is not a valid directory.\n" "$input_dir"
	exit 1
fi

terms_results_file="${input_dir}/terms_annotations_results.csv"

if [[ ! -f "$terms_results_file" ]]; then
	printf "\nError: '%s' does not exist.\n" "$terms_results_file"
	exit 1
fi

# look for genes in list column
genes_col=$(head -n 1 "$terms_results_file" | tr ',' '\n' | nl -v 1 | awk '$2 == "Genes_in_list" { print $1 }')

if [[ -z "$genes_col" ]]; then
	printf "\nError: No 'Genes_in_list' column was found in %s.\n" "$terms_results_file"
	exit 1
fi

if [[ -z "$genes_col" ]]; then
	printf "\nError: Column 'Genes_in_list' not found in %s.\n" "$terms_annotations_results"
	exit 1
fi

output_file="${input_dir}/excluded_genes"
printf "Gene\tN_Occurences\n" > "$output_file"

# find most common genes according to cutoff
tail -n +2 "$terms_results_file" | \
	awk -F',' -v col="$genes_col" '{print $col}' | \
	tr ' ' '\n' | \
	sed "s/'//g" | \
	sed '/^$/d' | \
	sort | \
	uniq -c | \
	awk -v cutoff="$cutoff" '$1 > cutoff { print $2 "\t" $1 }' | \
	sort -k2,2nr >> "$output_file"
