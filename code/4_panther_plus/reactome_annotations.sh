#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <species> <short_name>\n" "$0"
	exit 1
fi

species="$1"
short_name="$2"	# short_name to save file

echo "Downloading all Reactome Levels file"
curl -o uniprot2reactome https://reactome.org/download/current/UniProt2Reactome_All_Levels.txt

echo "Filtering downloaded Reactome file to species-specific pathways"
reactome_file="${short_name}_reactome"
awk -F'\t' -v sp="$species" '$6 == sp' uniprot2reactome > "$reactome_file"
rm -r uniprot2reactome

output_file="${short_name}_REAC_annotations"
awk -F'\t' '{ key = $2 "\t" $4; map[key] = (key in map ? map[key] "," $1 : $1) } END { for (k in map) print k "\t" map[k] }' "$reactome_file" > "$output_file"
rm -r "$reactome_file"

