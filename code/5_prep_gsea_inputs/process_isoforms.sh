#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
sed -i 's/\r$//' "/data/$input"	#replace /r

# control set?
if [ -z "$control" ]; then
	printf "No 'control' column(s) provided. Skipping isoform filtering.\n"
	exit 0
fi

# gene col set?
if [ -z "$gene" ]; then
	printf "Error: 'gene' column not defined in config.\n"
	exit 1
fi

header=$(head -n 1 "/data/$input" | sed $'s/\r//;s/^\xEF\xBB\xBF//')
IFS=$'\t' read -ra cols <<< "$header"

# gene col name to index
declare -A col_indices
for i in "${!cols[@]}"; do
	col=$(echo "${cols[$i]}" | xargs)	# Trim spaces
	col_indices["$col"]=$((i + 1))	# 1-based index for awk
done

# trim config gene
gene=$(echo "$gene" | xargs)
gene_col="${col_indices[$gene]}"

if [[ -z "$gene_col" ]]; then
	printf "Error: Gene column '%s' not found in header.\n" "$gene"
	printf "Available columns: %s\n" "${!col_indices[@]}"
	exit 1
fi

#parse control cols
IFS=',' read -ra control_cols <<< "$control"
temp_file="tmp_avg.tsv"

# multiple cols control = calculate avgs
if [ "${#control_cols[@]}" -gt 1 ]; then
	printf "Calculating average from columns: %s\n" "${control_cols[*]}"

	head -n 1 "/data/$input" | awk -v OFS='\t' '{ print $0, "control_avg" }' > "$temp_file"

	# calculate row-wise average
	tail -n +2 "/data/$input" | awk -F'\t' -v OFS='\t' -v cols="${control}" '
	BEGIN {
		split(cols, idxs, ",");
		for (i in idxs) {
			idxs[i] = idxs[i] + 0;  # ensure numeric
		}
	}
	{
		sum = 0; count = 0;
		for (i in idxs) {
			val = $(idxs[i]);
			if (val ~ /^[0-9.]+$/) {
				sum += val;
				count++;
			}
		}
		avg = (count > 0) ? sum / count : 0;
		out = $1;
		for (i = 2; i <= NF; i++) out = out OFS $i;
		print out, avg;
	}' >> "$temp_file"

	control_col=$(($(head -n 1 "$temp_file" | awk -F'\t' '{print NF}')))	# last column index
# use control cols provided
else
	cp "/data/$input" "$temp_file"
	control_col="${control_cols[0]}"
fi

# filter highest expressed isoforms
output_file="filtered_isoforms_gsea_${input%.tsv}.tsv"
(head -n 1 "$temp_file" && tail -n +2 "$temp_file" | \
 sort -t$'\t' -k${control_col},${control_col}nr | \
 awk -F'\t' -v col="$gene_col" '!seen[$col]++') > "$output_file"

rm "$temp_file"

printf "Isoform filtering completed based on control group samples average. Saved as: %s\n" "$output_file"
