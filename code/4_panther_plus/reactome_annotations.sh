#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <scientific_name> <short_name>\n" "$0"
	exit 1
fi

scientific_name="$1"
output_file="$2"

echo "Downloading all Reactome Levels file 'https://reactome.org/download/current/UniProt2Reactome_All_Levels.txt'"
curl -o uniprot2reactome https://reactome.org/download/current/UniProt2Reactome_All_Levels.txt

echo "Filtering Reactome pathways of '%s'." "$scientific_name" 
tmp_reactome="${scientific_name}_tmp"
awk -F'\t' -v sp="$scientific_name" '$6 == sp' uniprot2reactome > "$tmp_reactome"
rm -r uniprot2reactome

awk -F'\t' '{ key = $2 "\t" $4; map[key] = (key in map ? map[key] "," $1 : $1) } END { for (k in map) print k "\t" map[k] }' "$tmp_reactome" > "$output_file"
rm -r "$tmp_reactome"

