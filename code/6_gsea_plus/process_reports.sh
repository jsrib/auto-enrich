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

long_results="${analysis_dir}/long_results.csv"
short_results="${analysis_dir}/short_results.csv"
printf "Name,Phenotype,ListCount,ES,NES,NOM_p-val,FDR_q-val,FWER_p-val,RANK-AT-MAX,Leading_Edge\n" > "$long_results"

report_files=$(find "$analysis_dir" -maxdepth 1 -type f -name "gsea_report_for_*.tsv")

for file in $report_files; do
	report_filename=$(basename "$file")
	# extract phenotype name (this regex gets the last word before the numeric suffix)
	phenotype=$(echo "$report_filename" | sed -E 's/^gsea_report_for_(.*)_([0-9]+)\.tsv$/\1/' | awk -F'_' '{print $NF}')

	echo "Processing report: $report_filename (phenotype: $phenotype)"

	tail -n +2 "$file" | awk -v phenotype="$phenotype" -F '\t' '
		BEGIN { OFS="," }
		$8 < 0.05 {
			for (i = 1; i <= NF; i++) gsub(",", " ", $i);  # replace commas in fields
			print $1, phenotype, $4, $5, $6, $7, $8, $9, $10, $11
		}
	' >> "$long_results"
done

awk -F',' 'BEGIN {OFS=","} NR==1 {print $1,$2,$4,$6; next} {print $1,$2,$4,$6}' "$long_results" > "$short_results"
