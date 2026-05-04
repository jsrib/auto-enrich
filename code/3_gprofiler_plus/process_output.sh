#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <gprofiler_raw_output>\n" "$0"
	exit 1
fi

input_file="$1"
output_file="enrichment_fields.tsv"

if [ ! -f "$input_file" ]; then
	printf "Error: raw gprofiler output not found.\n"
	exit 1
fi

printf "TermID\tName\tDescription\tSource\tpValue_FDR\tPrecision\tRecall\tCoverage\tQuerySize\tIntersectionSize\tTermSize\tSource_order\tEffective_domain_size\tParents\tGroup_ID\tSignificant\n" > "$output_file"

# Process results parameters with jq
jq -r '.result[] | [
	.native,
	(.name | gsub(","; " ") | gsub("/"; "_")),
	(.description | gsub(","; " ")),
	(.source | gsub(":"; "_")),
	.p_value,
	.precision,
	.recall,
	(if .term_size > 0 then (.intersection_size / .term_size) else 0 end),
	.query_size,
	.intersection_size,
	.term_size,
	.source_order,
	.effective_domain_size,
	("[" + (.parents | map(gsub(","; "_")) | join("_")) + "]"),
	.group_id,
	.significant
] | @tsv' "$input_file" >> "$output_file"

if [ $? -eq 0 ]; then
	printf "\nProcessing successful. Output saved to %s\n\n" "$output_file"
else
	printf "Error: Processing results failed.\n"
	exit 1
fi