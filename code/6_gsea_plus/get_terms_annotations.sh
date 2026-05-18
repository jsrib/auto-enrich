#!/bin/bash

if [ $# -ne 3 ]; then
	printf "Usage: %s <results_dir> <enrichment_fields_file> <gmx_file>\n" "$0"
	exit 1
fi

results_dir="$1"
enriched_fields_file="$2"
gmx_file="$3"
output_file="${results_dir}/enriched_terms_annotations.tsv"

if [[ ! -d "$results_dir" ]]; then
	printf "Error: Results directory '%s' is not valid.\n" "$results_dir"
	exit 1
fi
if [[ ! -f "$enriched_fields_file" ]]; then
	printf "Error: Enrichment fields file '%s' not found.\n" "$enriched_fields_file"
	exit 1
fi
if [[ ! -f "$gmx_file" ]]; then
	printf "Error: Gene set file (GMX/GMT) '%s' not found.\n" "$gmx_file"
	exit 1
fi

# coverage coreenrichmentsize/termsize
printf "Name\tSource\tPhenotype\tCoverage\tCoreEnrichmentSize\tTermSize\tGenes_in_CoreEnrichment\tGenes_in_term\n" > "$output_file"

# read results
tr -d '\r' < "$enriched_fields_file" | tail -n +2 | while IFS=$'\t' read -r name source phenotype es nes nom_p fdr_q fwer_p rank_at_max size leading_edge; do
	target_file="${results_dir}/${name}.tsv"
	if [[ ! -f "$target_file" && -d "${results_dir}/raw_GSEA_output" ]]; then
		target_file="${results_dir}/raw_GSEA_output/${name}.tsv"
	else
		printf "Detailed results file not found for '%s'" "$name" 
	fi

	# get core enrichment genes from detailed report file of the term
	core_genes=""
	core_size=0

	if [[ -f "$target_file" ]]; then
		# Capture clean comma-separated list of core enrichment genes from Column 2
		core_genes=$(awk -F '\t' '
			NR == 1 {
				for (i = 1; i <= NF; i++) {
					if ($i ~ /CORE/ && $i ~ /ENRICHMENT/) { col_idx = i }
				}
				next
			}
			col_idx && ($col_idx == "Yes" || $col_idx == "yes") { 
				print $2 
			}
		' "$target_file" | paste -sd "," -)
		
		if [[ -n "$core_genes" ]]; then
			core_size=$(echo "$core_genes" | tr ',' '\n' | wc -l | xargs)
		fi
	fi

	# get term genes from used GMX file in analysis
	gmx_genes=""
	gmx_size=0

	gmx_line=$(grep -P "^${name}\t" "$gmx_file")
	if [[ -n "$gmx_line" ]]; then
		# get genes block
		gmx_genes_raw=$(printf "%s\n" "$gmx_line" | cut -f3-)
		# parse into a comma-separated list
		gmx_genes=$(printf "%s\n" "$gmx_genes_raw" | tr '\t' '\n' | grep -v '^$' | paste -sd "," -)
		gmx_size=$(printf "%s\n" "$gmx_genes_raw" | tr '\t' '\n' | grep -v -c '^$')
	fi

	# calculate coverage
	coverage="0.0000"
	if [[ $gmx_size -gt 0 ]]; then
		coverage=$(awk "BEGIN { printf \"%.4f\", ($core_size / $gmx_size) }")
	fi

	# write final output
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$name" "$source" "$phenotype" "$coverage" "$core_size" "$gmx_size" \
		"$core_genes" "$gmx_genes" >> "$output_file"
done

echo "Coverage profile successfully generated at: $output_file"