#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
output_file="selected_genes_list"

# input = input expression matrix file name (in /data)
# gene = col idx of genes identifier (geneIDs)
# selected = col idx with flagged genes (1)

if [ -n "${selected:-}" ]; then
	select_col=$((selected - 1))
	gene_col=${gene}
	gene_col=$((gene_col - 1))
	tail -n +2 "/data/$input" | while IFS=$'\t' read -r -a columns; do
		if [ "${columns[$select_col]}" = "1" ]; then
			printf "%s\n" "${columns[$gene_col]}" >> "$output_file"
		fi
	done
fi