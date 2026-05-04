#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config_file>\n" "$0"
	exit 1
fi

config="$1"
output="column_header_mapping.txt"

source "$config"

IFS=$'\t' read -r -a headers < "/data/$input"

# function: convert 1-based index
get_header() {
	local index=$1
	printf "%s" "${headers[$((index - 1))]}"
}

printf "Mapping of Config Variables to Header Names\n\n" > "$output"

if [[ -n "$gene" ]]; then
	printf "Gene (column %s): %s\n" "$gene" "$(get_header "$gene")" >> "$output"
fi

for var in "${!avg@}"; do
	val="${!var}"
	if [[ -n "$val" ]]; then
		# one or multiple?
		if [[ "$val" =~ ^[0-9]+$ ]]; then
			printf "%s (column %s): %s\n" "$var" "$val" "$(get_header "$val")" >> "$output"
		else
			IFS=',' read -r -a idxs <<< "$val"
			names=()
			for idx in "${idxs[@]}"; do
				[[ -z "$idx" ]] && continue
				names+=("$(get_header "$idx")")
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