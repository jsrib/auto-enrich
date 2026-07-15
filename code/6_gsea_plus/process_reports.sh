#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <{results_dir}> <output_file>\n" "$0"
	exit 1
fi

results_dir="$1"
output_file="$2"

file_count=$(find "${results_dir}" -maxdepth 1 -type f -name "gsea_report_for_*.tsv" | wc -l)

if [ "$file_count" -eq 0 ]; then
	printf "Error: No files matching 'gsea_report_for_*.tsv' found in %s\n" "$results_dir"
	exit 1
fi

printf "Name\tSource\tPhenotype\tES\tNES\tNOM_p-val\tFDR_q-val\tFWER_p-val\tRANK-AT-MAX\tIntersectionSize\tLeading_Edge\n" > "$output_file"

# Use a safe 'while read' loop to handle paths cleanly
find "${results_dir}" -maxdepth 1 -type f -name "gsea_report_for_*.tsv" | while read -r file; do
	report_filename=$(basename "$file")
	
	# get phenotype name
	phenotype=$(echo "$report_filename" | sed -E 's/^gsea_report_for_(.*)_([0-9]+)\.tsv$/\1/' | awk -F'_' '{print $NF}')

	echo "Processing report: $report_filename (phenotype: $phenotype)"

	# loop over enrichment fiels of gsea report (join phenotpes)
	tail -n +2 "$file" | awk -v phenotype="$phenotype" -F '\t' '
		BEGIN { 
			OFS="\t" 
		}
		$8 < 0.05 {
			term = $1
			size = $4
			ES = $5
			NES = $6
			pVal = $7
			pVal_FDR = $8
			pVal_FWER = $9
			rank = $10
			leading = $11
			
			# extract source (e.g., REACTOME from REACTOME_GLYCOLYSIS)
			idx = index(term, "_")
			source = (idx > 0) ? substr(term, 1, idx - 1) : "UNKNOWN"

			print term, source, phenotype, ES, NES, pVal, pVal_FDR, pVal_FWER, rank, size, leading
		}
	' >> "$output_file"
done

echo "Combined results saved to: $output_file"