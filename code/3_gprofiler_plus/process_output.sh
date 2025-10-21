#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <gprofiler_raw_output>\n" "$0"
	exit 1
fi

input_file="$1"

if [ ! -f "$input_file" ]; then
	printf "Error: raw gprofiler output not found.\n"
	exit 1
fi

short_file="short_results.csv"
long_file="long_results.csv"

printf "TermID,Name,P-Value_FDR,Source\n" > "$short_file"
printf "TermID,Name,Description,P-Value_FDR,Precision,Recall,ListCount,TermCount,Query_size,Source,Source_order,Effective_domain_size,Parents,Group_ID,Significant\n" > "$long_file"

# process json one to one
jq -c '.result[]' "$input_file" | while IFS= read -r item; do
	termID=$(jq -r '.native' <<< "$item")
	name=$(jq -r '.name | gsub(","; " ") | gsub("/"; "_")' <<< "$item")
	description=$(jq -r '.description | gsub(","; " ")' <<< "$item")
	pval=$(jq -r '.p_value' <<< "$item")
	precision=$(jq -r '.precision' <<< "$item")
	recall=$(jq -r '.recall' <<< "$item")
	inter_size=$(jq -r '.intersection_size' <<< "$item")
	term_size=$(jq -r '.term_size' <<< "$item")
	query_size=$(jq -r '.query_size' <<< "$item")
	source=$(jq -r '.source | gsub(":"; "_")' <<< "$item")
	source_order=$(jq -r '.source_order' <<< "$item")
	eff_domain=$(jq -r '.effective_domain_size' <<< "$item")
	parents=$(jq -r '.parents | "[" + (map(gsub(","; "_")) | join("_")) + "]"' <<< "$item")
	group_id=$(jq -r '.group_id' <<< "$item")
	significant=$(jq -r '.significant' <<< "$item")

	printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
		"$termID" "$name" "$description" "$pval" "$precision" "$recall" "$inter_size" "$term_size" "$query_size" "$source" "$source_order" "$eff_domain" "$parents" "$group_id" "$significant" >> "$long_file"

	printf '%s,%s,%s,%s\n' "$termID" "$name" "$pval" "$source" >> "$short_file"
done

if [ "$(wc -l < "$short_file")" -gt 1 ] && [ "$(wc -l < "$long_file")" -gt 1 ]; then
	printf "\nProcessing successful. Output saved to %s and %s\n\n" "$short_file" "$long_file"
else
	printf "Error: Processing results failed.\n"
	exit 1
fi
