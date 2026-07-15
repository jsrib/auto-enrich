#!/bin/bash

if [ $# -lt 2 ]; then
	printf "Usage: %s <input_file> <max_n_occurences> <output_file> \n" "$0"
	exit 1 
fi

input_file="$1"
cutoff="$2"
output_file="${3:-excluded_genes}"

if [[ ! -f "$input_file" ]]; then
	printf "Error: File '%s' not found." "$input_file"
	exit 1
fi

# determine col idxs
genes_col=$(head -n 1 "$input_file" | \
awk -F'\t' '
{
for (i=1; i<=NF; i++) {
	gsub(/^ +| +$/, "", $i)
	if ($i == "Genes_in_intersection" || $i == "Genes_in_CoreEnrichment") {
		print i
		exit
	}
}
}')

if [[ -z "$genes_col" ]]; then
	printf "GENE OCCURRENCES Error: Neither 'Genes_in_intersection' nor 'Genes_in_CoreEnrichment' column found in '%s'.\n" "$input_file"
	exit 1
fi

printf "Gene\tN_Occurences\n" > "$output_file"

# find most common genes according to cutoff
tail -n +2 "$input_file" | \
	awk -F'\t' -v col="$genes_col" '{print $col}' | \
	tr ',; ' '\n' | \
	sed "s/'//g" | \
	sed '/^$/d' | \
	sort | \
	uniq -c | \
	awk -v cutoff="$cutoff" '$1 > cutoff { print $2 "\t" $1 }' | \
	sort -k2,2nr >> "$output_file"
