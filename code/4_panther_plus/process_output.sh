#!/bin/bash

if [[ $# -ne 1 ]]; then
	printf "Usage: %s <panther_JSON_file>\n" "$0"
	exit 1
fi

input_file="$1"

if [ ! -f "$input_file" ]; then
	printf "Error: input file not found.\n"
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

output_file="results_${source}.csv"
printf "TermID,Name,P-Value,P-Value_FDR,Fold_Enrichment,Plus_Minus,Source,ListCount,TermCount\n" > "$output_file"

# extract data and filter results fdr < 0.05
jq -r --arg source "$source" \
	'.results.result[] | select(.fdr < 0.05) | "\(.term.id),\(.term.label | gsub(","; " ") | gsub("/"; "-")),\(.pValue),\(.fdr),\(.fold_enrichment),\(.plus_minus),\($source | gsub(":"; "_")),\(.number_in_list),\(.number_in_reference)"' \
	"$input_file" >> "$output_file"

if [ $? -ne 0 ]; then
	printf "Error: Processing results failed.\n"
	exit 1
fi
