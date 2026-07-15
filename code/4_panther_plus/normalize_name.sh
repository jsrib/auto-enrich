#!/bin/bash

if [ $# -ne 1 ]; then
    printf "Usage: %s <taxon_id>\n" "$0"
    exit 1
fi

taxon_id="$1"
sup_genomes="supported_genomes.json"

# Fetch the supported genomes list from PANTHER
curl -s -X GET "https://pantherdb.org/services/oai/pantherdb/supportedgenomes" \
	-H "accept: application/json" \
	-o "$sup_genomes"

if [ ! -s "$sup_genomes" ]; then
	printf "❌ [MODULE 4] Error: Failed to fetch supported genomes from PANTHER API.\n"
	exit 1
fi

# extract long_name and name from official PANTHER name
read_data=$(jq -r --arg tid "$taxon_id" '
	.search.output.genomes.genome[] 
	| select((.taxon_id | tonumber) == ($tid | tonumber)) 
	| "\(.long_name)\t\(.name)"
' "$sup_genomes")

if [ -z "$read_data" ]; then
	printf "❌ [MODULE 4] Error: Taxon ID '%s' not found in PANTHER supported genomes.\n" "$taxon_id"
	exit 1
fi

scientific_name=$(echo "$read_data" | cut -f1)
common_name=$(echo "$read_data" | cut -f2)

#printf "Taxon ID:   %s\n" "$taxon_id"
#printf "Scientific Name:  %s\n" "$scientific_name"
#printf "Common Name: %s\n" "$common_name"
