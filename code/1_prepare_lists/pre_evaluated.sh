#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
output_file="selected_genes_list"

if [ -n "${select:-}" ]; then
	select_col=$((select - 1))
	gene_col=${gene}
	gene_col=$((gene_col - 1))
	tail -n +2 "/data/$input" | while IFS=$'\t' read -r -a columns; do
		if [ "${columns[$select_col]}" = "1" ]; then
			printf "%s\n" "${columns[$gene_col]}" >> "$output_file"
		fi
	done
fi