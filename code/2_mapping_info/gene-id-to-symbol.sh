#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <gene_ids_list_file>\n" "$0"
	exit 1
fi

input_file="$1"
output_file="gene_symbols"

mapfile -t gene_array < <(awk 'NF' "$input_file")

printf "GeneID\tOfficialSymbol\tFullName\n" > "$output_file"

for GENE_ID in "${gene_array[@]}"; do
	URL="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=gene&id=${GENE_ID}&retmode=json"
	RESPONSE=$(curl -s "$URL")
	
	OFFICIAL_SYMBOL=$(echo "$RESPONSE" | jq -r ".result[\"$GENE_ID\"].name")
	OFFICIAL_NAME=$(echo "$RESPONSE" | jq -r ".result[\"$GENE_ID\"].description")
	printf "\nGene ID: %s\n" "$GENE_ID"
	printf "Official Symbol: %s\n" "$OFFICIAL_SYMBOL"
	printf "Official Full Name: %s\n" "$OFFICIAL_NAME"

	printf "%s\t%s\t%s\n" "$GENE_ID" "$OFFICIAL_SYMBOL" "$OFFICIAL_NAME" >> "$output_file"
done