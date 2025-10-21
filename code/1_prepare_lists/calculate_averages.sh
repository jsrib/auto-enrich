#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
output_file="output_averages"

gene_col=$((gene - 1))

declare -A avg_instructions
avg_keys=()

# parse avgX keys
for var in $(compgen -v | grep -E '^avg[0-9]+$'); do
	avg_keys+=("$var")
	avg_instructions[$var]="${!var}"
done

header="gene"
for key in "${avg_keys[@]}"; do
	header+=$'\t'"$key"
done
printf "%s\n" "$header" > "$output_file"

printf "Processing averages...\n"

tail -n +2 "/data/$input" | while IFS=$'\t' read -r -a columns; do
	if [[ $gene_col -ge 0 && $gene_col -lt ${#columns[@]} ]]; then
		gene="${columns[$gene_col]}"
	else
		printf "Warning: Invalid gene column index\n" >&2
		continue
	fi

	output="$gene"

	# loop each avgX key
	for key in "${avg_keys[@]}"; do
		value="${avg_instructions[$key]}"
		# if commas treat as list of cols
		if [[ "$value" == *,* ]]; then
			IFS=',' read -r -a col_indices <<< "$value"
			sum=0
			count=0
			for idx in "${col_indices[@]}"; do
				col_idx=$((idx - 1))
				if [[ $col_idx -ge 0 && $col_idx -lt ${#columns[@]} ]]; then
					val="${columns[$col_idx]}"
					if [[ "$val" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
						sum=$(echo "$sum + $val" | bc -l)
						((count++))
					fi
				fi
			done
			avg_val=$([[ $count -gt 0 ]] && echo "scale=5; $sum / $count" | bc -l || echo "0")
		else
			# if single index, get precalculated average
			col_idx=$((value - 1))
			if [[ $col_idx -ge 0 && $col_idx -lt ${#columns[@]} ]]; then
				avg_val="${columns[$col_idx]}"
			else
				avg_val="N/A"
			fi
		fi

		output+=$'\t'"$avg_val"
	done

	printf "%s\n" "$output" >> "$output_file"
done

sed -i 's/\r//' "$output_file"