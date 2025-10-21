#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <results_dir>\n" "$0"
	exit 1
fi

input_dir="$1"

if [[ ! -d "$input_dir" ]]; then
	printf "\nError: '%s' is not a valid directory.\n" "$input_dir"
	exit 1
else
	analysis_dir="${input_dir}"
fi

# save GSEA raw output
raw_out_dir="${analysis_dir}/raw_GSEA_output"
mkdir -p "$raw_out_dir"
find "$analysis_dir" -mindepth 1 -maxdepth 1 ! -name "raw_GSEA_output" -exec mv {} "$raw_out_dir/" \;

printf "Moved all original GSEA output to: %s\n" "$raw_out_dir"

# get reports file for results
report_files=$(find "$raw_out_dir" -type f -name "gsea_report_*.tsv")
for file in $report_files; do
	cp "$file" "$analysis_dir/"
	echo "Copied $(basename "$file") to $analysis_dir"
done
