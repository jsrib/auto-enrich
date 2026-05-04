#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
output="column_header_mapping.txt"

IFS=$'\t' read -r -a headers < "/data/$input"

# function: convert 1-based index
one_based() {
	local index=$1
	printf "%s" "${headers[$((index - 1))]}"
}

if [[ -n "$gene" ]]; then
	printf "Gene column : %s\n" "$gene" "$(one_based "$gene")" >> "$output"
fi

for var in "${!avg@}"; do
	val="${!var}"
	if [[ -n "$val" ]]; then
		# one or multiple?
		if [[ "$val" =~ ^[0-9]+$ ]]; then
			printf "%s (column %s): %s\n" "$var" "$val" "$(one_based "$val")" >> "$output"
		else
			IFS=',' read -r -a idxs <<< "$val"
			names=()
			for idx in "${idxs[@]}"; do
				[[ -z "$idx" ]] && continue
				names+=("$(one_based "$idx")")
			done
			IFS=','; printf "%s (columns %s): %s\n" "$var" "$val" "${names[*]}" >> "$output"; IFS=$' \t\n'
		fi
	fi
done

for var in "${!cond@}"; do
	val="${!var}"
	if [[ -n "$val" ]]; then
		printf "%s: %s\n" "$var" "$val" >> "$output"
	fi
done

printf "Minimum expression threshold: %s\n" "${expression_min:-Not set}" >> "$output"
printf "Maximum expression threshold: %s\n" "${expression_max:-Not set}" >> "$output"