#!/bin/bash

set -euo pipefail

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
sed -i 's/\r$//' "/data/$input"

if [[ -z "${control:-}" ]]; then
	printf "Error: 'control' column must be defined in config.\n"
	exit 1
fi

if [[ -z "${gene:-}" ]]; then
	printf "Error: 'gene' column must be defined in config.\n"
	exit 1
fi

header=$(head -n 1 "/data/$input" | sed $'s/\r//;s/^\xEF\xBB\xBF//')
IFS=$'\t' read -ra cols <<< "$header"

declare -A col_indices
for i in "${!cols[@]}"; do
	col=$(echo "${cols[$i]}" | xargs)
	col_indices["$col"]=$((i + 1))
done

gene=$(echo "$gene" | xargs)
control=$(echo "$control" | xargs)

gene_col="${col_indices[$gene]:-}"
control_col="${col_indices[$control]:-}"

if [[ -z "$gene_col" ]]; then
	printf "Error: Gene column '%s' not found.\n" "$gene"
	exit 1
fi

if [[ -z "$control_col" ]]; then
	printf "Error: Control column '%s' not found.\n" "$control"
	exit 1
fi

output_file="filtered_isoforms_${input%.tsv}.tsv"

(
	head -n 1 "/data/$input"
	tail -n +2 "/data/$input" | \
	sort -t$'\t' -k${control_col},${control_col}nr | \
	awk -F'\t' -v g="$gene_col" '!seen[$g]++'
) > "$output_file"

printf "Filtering complete: highest '%s' per gene retained.\n" "$control"
printf "Output saved to: %s\n" "$output_file"