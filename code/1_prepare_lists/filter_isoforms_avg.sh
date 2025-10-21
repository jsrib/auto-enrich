#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
output="filtered_isoforms_${input}"

# check control var
if [ -n "${control:-}" ]; then
	# numeric?
	if ! [[ "$gene" =~ ^[0-9]+$ ]] || ! [[ "$control" =~ ^[0-9]+$ ]]; then
		echo "Error: 'gene' and 'control' must be numeric column indices (starting at 1)."
		exit 1
	fi
	if ! tail -n +2 "/data/$input" | cut -f"$control" | grep -vqE '^[0-9]+$'; then
		echo "Error: Non-integer value(s) found in control column $control."
		exit 1
	fi
	(head -n 1 "/data/$input" && tail -n +2 "/data/$input" | \
	 sort -t$'\t' -k"$control","$control"nr | \
	 awk -F'\t' -v col="$gene" '!seen[$col]++') > "$output"
else
	printf "No 'control' column provided in %s. Skipping isoform filtering.\n" "$1"
	exit 0
fi