#!/bin/bash

# --- 1. Setup and Validation ---
if [ "$#" -ne 2 ]; then
	printf "Usage: %s <config> <input>\n" "$0"
	exit 1
fi

source "$1"
input_file="/data/$2"

if [ ! -f "${input_file}" ]; then
	printf "❌ [MODULE 5] Input File Missing: %s\n" "${input_file}" >&2
	exit 1  
fi

# ensure valid gene index
if ! [[ "$gene" =~ ^[0-9]+$ ]] || [ "$gene" -le 0 ]; then
	printf "❌ [MODULE 5] Configuration Error: Gene column index '%s' is invalid.\n" "$gene" >&2
	exit 1
fi

# ensure valid prerank variables
mapfile -t target_vars < <(compgen -v prerank)
if [ ${#target_vars[@]} -eq 0 ]; then
	printf "❌ [MODULE 5] Configuration Error: No 'prerank' variables found.\n" >&2
	exit 1
fi

# map column names to indices
header=$(head -n 1 "$input_file" | tr -d '\r')
IFS=$'\t' read -ra columns <<< "$header"

declare -A col_indices
for i in "${!columns[@]}"; do
	col="${columns[$i]}"
	[[ -z "$col" ]] && continue
	col_indices["$col"]=$((i + 1))
done

# sort column names by length descend to prevent partial matches
sorted_colnames=$(printf "%s\n" "${!col_indices[@]}" | awk '{print length, $0}' | sort -rn | cut -d' ' -f2-)

# process each prerank formula
for varname in "${target_vars[@]}"; do
	[[ "$varname" == "target_vars" ]] && continue
	
	formula="${!varname}"
	[[ -z "$formula" ]] && continue

	# validate that all variables in the formula are present in the header
	awk_formula="$formula"
	required_cols=$(echo "$formula" | grep -o '[[:alnum:]_]\+')
	
	for req in $required_cols; do
		if [[ -z "${col_indices[$req]}" ]]; then
			printf "❌ Error: Column '%s' in %s not found in header.\n" "$req" "$varname" >&2
			exit 1
		fi
	done

	# replace variable names with awk column references
	for name in $sorted_colnames; do
		idx="${col_indices[$name]}"
		awk_formula=$(echo "$awk_formula" | sed "s/\b$name\b/(\$$idx+1)/g")
	done

	# prepare output filename
	safe_name=$(echo "$formula" | sed 's/[^[:alnum:]]/_/g')
	outfile="log2FC_${safe_name}.rnk"

	printf "Calculating %s: %s. " "$varname" "$formula"

	# awk to calculate the formula, filter for positive values, log2 transform, and sort
	awk -F'\t' -v OFS='\t' -v g="$gene" '
	NR > 1 {
		# Evaluate the translated formula
		val = ('"$awk_formula"');
		
		if (val > 0) {
			log2val = log(val) / log(2);
			print $g, log2val;
		}
	}' "$input_file" | sort -k2,2gr > "$outfile"

	printf "Saved filename: %s\n" "$outfile"
done