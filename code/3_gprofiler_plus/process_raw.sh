#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
	printf "Usage: %s <gprofiler_raw_output> <results_file>\n" "$0"
	exit 1
fi

input_file="$1"
output_file="$2"

if [ ! -f "$input_file" ]; then
	printf "❌ [MODULE 3] Error: raw gprofiler output not found.\n"
	exit 1
fi

printf "Processing enrichment fields...\n"

# process the raw gprofiler output, extracting relevant fields and reformatting them into a tab-separated file with a header 
printf "TermID\tName\tDescription\tSource\tpValue_FDR\tPrecision\tRecall\tQuerySize\tCoverage\tIntersectionSize\tTermSize\tSource_order\tEffective_domain_size\tParents\tGroup_ID\tSignificant\n" > "$output_file"

jq -r '.result[] | [
	.native,
	(.name | gsub("/"; "_")),
	(.description | gsub("/"; "_")),
	(.source | gsub(":"; "_")),		### to change in line with panther and gsea
	.p_value,
	.precision,
	.recall,
	.query_size,
	(if .term_size > 0 then (.intersection_size / .term_size) else 0 end),
	.intersection_size,
	.term_size,
	.source_order,
	.effective_domain_size,
	("[" + (.parents | map(gsub(","; "_")) | join("_")) + "]"),
	.group_id,
	.significant
	] | @tsv' "$input_file" >> "$output_file"

if [ $? -eq 0 ]; then
	printf "Processing successful. Output saved to '%s'.\n" "$output_file"
else
	printf "❌ [MODULE 3] Error: Processing raw results failed.\n"
	exit 1
fi