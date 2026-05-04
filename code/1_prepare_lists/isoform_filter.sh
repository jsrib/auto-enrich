#!/bin/bash

if [ $# -ne 3 ]; then
	printf "Usage: %s <config> <input> <output>\n" "$0"
	exit 1
fi

source "$1"
# possible new input if averages preivous calculated
input_file="/data/$2"
output_file="$3"

if [ ! -f "${input_file}" ]; then
	printf "❌ [MODULE 1] Configuration Error: Input expression matrix file '%s' not found for isoform filtering.\n" "${input_file}" >&2
	exit 1
fi

# find the index of the column name provided in $isoform
isoform_idx=$(head -n 1 "${input_file}" | tr '\t' '\n' | grep -nx "$isoform" | cut -d: -f1)
if [ -z "$isoform_idx" ]; then
	printf "❌ [MODULE 1] Column name error: Column name '%s' not found in the header of /data/%s" "" "$isoform" "$input_file" >&2
	exit 1
fi

# sort and keep unique genes
(
	head -n 1 "${input_file}" && \
	tail -n +2 "${input_file}" | \
	sort -t$'\t' -k"${isoform_idx},${isoform_idx}nr" | \
	awk -F'\t' -v col="$gene" '!seen[$col]++'
) > "$output_file"
