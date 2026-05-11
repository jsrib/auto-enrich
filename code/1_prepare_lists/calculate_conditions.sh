#!/bin/bash

if [ $# -ne 3 ]; then
	printf "Usage: %s <config> <input> <output>\n" "$0"
	exit 1
fi

source "$1"
# possible new input if averages or conditions preivous calculated
input_file="$2"
output_file="$3"

if [ ! -f "${input_file}" ]; then
	printf "❌ [MODULE 1] Input File Missing: Input expression matrix file '%s' not found for conditions calculations.\n" "${input_file}" >&2
	exit 1
fi

cond_string=""
for var in $(compgen -v | grep '^cond[0-9]\+$'); do
	formula="${!var}"
	cond_string+="${var}:${formula}|"
done
cond_string="${cond_string%|}"

# calculations with AWK
awk -F'\t' -v OFS='\t' -v conds="$cond_string" '
BEGIN {
	split(conds, pairs, "|")
	for (i in pairs) {
		split(pairs[i], parts, ":");
		cond_names[i] = parts[1];      # "cond1"
		cond_formulas[i] = parts[2];   # "Control/Exp"
	}
	num_conds = length(cond_names);
}

# map header and create new
NR == 1 {
	sub(/\r$/, "", $0);
	
	for (i = 1; i <= NF; i++) {
		col_map[$i] = i;
	}
	
	printf "%s", $0;
	# add new cond columns
	for (i=1; i<=num_conds; i++) {
		printf "\tlog2_%s", cond_names[i];
	}
	printf "\n";
	next;
}

# handle calculations
{
	sub(/\r$/, "", $0);
	
	printf "%s", $0;
	for (i = 1; i <= num_conds; i++) {
		expr = cond_formulas[i];

		# sub column names for values
		for (name in col_map) {
			gsub("\\<" name "\\>", $(col_map[name]), expr);
		}

		# wrap expression into log2
		command = "echo \"scale=10; " expr "\" | bc -l 2>/dev/null"
		
		if ((command | getline result) > 0) {
			# Check if bc returned an empty string or error
			if (result == "") {
				printf "\tNaN";
			} else {
				printf "\t%.4f", result;
			}
		} else {
			printf "\tN/A";
		}
		close(command);
	}
	printf "\n";
}' "$input_file" > "$output_file"