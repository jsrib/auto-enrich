#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <gene_ids_list> <output_file>\n" "$0"
	exit 1
fi

input_file="$1"
output_file="$2"

mapfile -t gene_array < <(awk 'NF' "$input_file")

printf "GeneID\tOfficialSymbol\tFullName\n" > "$output_file"

for gene_id in "${gene_array[@]}"; do
	url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=gene&id=${gene_id}&retmode=json"
	response=$(curl -s "$url")
	
	symbol=$(echo "$response" | jq -r ".result[\"$gene_id\"].name")
	name=$(echo "$response" | jq -r ".result[\"$gene_id\"].description")
	printf "Querying: %s\n" "$gene_id"
	printf "Mapped official Symbol and Name: %s, %s\n" "$symbol" "$name"
	printf "%s\t%s\t%s\n" "$gene_id" "$symbol" "$name" >> "$output_file"
done