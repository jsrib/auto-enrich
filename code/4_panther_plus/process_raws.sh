#!/bin/bash
set -eo pipefail

if [[ $# -ne 1 ]]; then
	printf "Usage: %s <panther_raw_output>\n" "$0"
	exit 1
fi

input_file="$1"

if [ ! -f "$input_file" ]; then
	printf "❌ [MODULE 4] Error: raw panther output JSON file not found.\n"
	exit 1
fi

# remove output_ and get source
source="${input_file#output_}"
source="${source#ANNOT_TYPE_ID_}"
source="${source%.json}"

case "$source" in
	"GO_0003674") source="GO_MF" ;;
	"GO_0008150") source="GO_BP" ;;
	"GO_0005575") source="GO_CC" ;;
	"REACTOME_PATHWAY") source="REAC";;
esac

source_results="results_${source}.tsv"
printf "TermID\tName\tSource\tpValue\tpValue_FDR\tFold_Enrichment\tDirection\tQuerySize\tCoverage\tIntersectionSize\tTermSize\n" > "$source_results"

# extract data and filter results pValue < 0.05
jq -r --arg source "$source" '
	# capture query size first (number of actually mapped genes from the input list)
	.results.input_list.mapped_count as $query_size
	# capture enrichment fields
	| .results.result[]
	| select(.fdr < 0.05) 
	| [
		.term.id, 
		(.term.label | gsub("/"; "-")), 
		($source | gsub(":"; "_")), 
		.pValue,
		.fdr,
		.fold_enrichment,
		.plus_minus,
		$query_size,
		(if .number_in_reference > 0 then (.number_in_list / .number_in_reference) else 0 end),
		.number_in_list,
		.number_in_reference
	  ]
	| @tsv' "$input_file" >> "$source_results"

if [ $? -ne 0 ]; then
	printf "❌ [MODULE 4] Error: Processing results failed.\n"
	exit 1
fi
