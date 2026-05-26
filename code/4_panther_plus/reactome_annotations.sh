#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <scientific_name> <short_name>\n" "$0"
	exit 1
fi

scientific_name="$1"
output_file="$2"

reactome_url="https://reactome.org/download/current/UniProt2Reactome_All_Levels.txt"
printf "Downloading all Reactome Levels file ('https://reactome.org/download/current/UniProt2Reactome_All_Levels.txt')\n"
curl -o uniprot2reactome $reactome_url

printf "Filtering Reactome pathways of '%s'.\n" "$scientific_name"
tmp_reactome="${scientific_name}_tmp"
awk -F'\t' -v sp="$scientific_name" '$6 == sp' uniprot2reactome > "$tmp_reactome"
rm -r uniprot2reactome

generation_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Add metadata to the start of the output file
{
	echo "!Source: $reactome_url"
	echo "!Organism: $scientific_name"
	echo "!Description: UniProt identifiers mapped to Reactome pathways."
	echo "!Generation_Date: $generation_date"
	echo "!Generate_by: auto-Enrich Pipeline"
	echo "!Note: Reactome is a manually curated database of pathways and reactions."
	echo "!License: Creative Commons Attribution 4.0 International (CC BY 4.0)"
} > "$output_file"

awk -F'\t' '
{ 
	key = $2 "\t" $4; 
	if (!seen[key, $1]++) {
		if (list[key] == "") {
			list[key] = $1
		} else {
			list[key] = list[key] "," $1
		}
	}
} 
END { 
	for (k in list) print k "\t" list[k] 
}
' "$tmp_reactome" >> "$output_file"
rm -r "$tmp_reactome"

