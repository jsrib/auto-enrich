#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <config_file> <averages_file>\n" "$0"
	exit 1
fi

source "$1"
input_file="$2"
output_file="output_conditions"

declare -A conditions
c_keys=()

for var in $(compgen -v | grep '^cond[0-9]\+$'); do
	conditions[$var]="${!var}"
	c_keys+=("$var")
done

IFS=$'\t' read -r -a header_columns < "$input_file"

# new header (original cols + conds names)
new_header="$(IFS=$'\t'; echo "${header_columns[*]}")"
for cond in "${c_keys[@]}"; do
	new_header+=$'\t'"$cond"
done
printf "%s\n" "$new_header" > "$output_file"

printf "Calculating condition values...\n"

tail -n +2 "$input_file" | while IFS=$'\t' read -r -a columns; do
	new_line="$(IFS=$'\t'; echo "${columns[*]}")"
	for cond in "${c_keys[@]}"; do
		formula="${conditions[$cond]}"
		eval_expr="$formula"
		for ((i=0; i<${#header_columns[@]}; i++)); do
			col_name="${header_columns[$i]}"
			col_value="${columns[$i]}"
			col_value_clean=$(echo "$col_value" | tr -d '\r' | xargs)
			if [[ -n "$col_value_clean" ]]; then
				eval_expr=$(echo "$eval_expr" | sed "s/\b${col_name}\b/${col_value_clean}/g")
			else
				eval_expr="INVALID"
				break
			fi
		done
		# evaluate expression
		if [[ "$eval_expr" == "INVALID" ]]; then
			result="N/A"
		else
			result=$(echo "$eval_expr" | bc -l 2>/dev/null)
			# validate and format
			if [[ -z "$result" || ! "$result" =~ ^-?([0-9]*\.[0-9]+|[0-9]+)$ ]]; then
				result="N/A"
			else
				result=$(printf "%.4f" "$result")
			fi
		fi

		new_line+=$'\t'"$result"
	done

	printf "%s\n" "$new_line" >> "$output_file"
done
