#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <config> <output>\n" "$0"
	exit 1
fi

source "$1"
basename=$(basename "$input")
output_file="$2"

# required variables check
required_vars=("input" "gene" "number_groups" "number_samples" "samples" "groups")
for var in "${required_vars[@]}"; do
	if [[ -z "${!var}" ]]; then
		printf "❌ [MODULE 1] Configuration Error: Variable '%s' is undefined or empty.\n" "$var" >&2
		exit 1
	fi
done

#prepare new header
new_header=$(echo "$groups" | awk '{for(i = 1; i <= NF; i += 2) printf "\t"$i}')
head -n +1 "/data/${input}" | tr -d '\r' | awk -v new="$new_header" '{print $0 new}' > "$output_file"

# calculate averages group per row
tail -n +2 "/data/${input}" | awk -v samps="$samples" -v grps="$groups" '
BEGIN {
	FS="\t"; OFS="\t";
	split(samps, s, ",");
	n_groups = split(grps, g, " ");
}
{
	printf "%s", $0
	current_idx = 1;

	# loop each group
	for (i = 1; i <= n_groups; i+=2) {
		group_name=g[i]
		group_size=g[i+1]

		# calculate sum of cols from current group
		sum=0
		for (j=0; j < group_size; j++) {
			col = s[current_idx + j];
			sum += $col;
		}

		avg = (group_size > 0) ? sum / group_size : 0;
		# append average with 4 decimals
		printf "\t%.4f", avg;

		current_idx += group_size
	}
	printf "\n";
}' >> "$output_file"

sed -i 's/\r//' "$output_file"