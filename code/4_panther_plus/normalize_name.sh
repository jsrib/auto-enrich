#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <species>\n" "$0"
	exit 1
fi

species="$1"

curl -s -X GET "https://pantherdb.org/services/oai/pantherdb/supportedgenomes" \
	 -H "accept: application/json" \
	 -o supported_genomes -w "Status: %{http_code}\n"
sup_genomes="supported_genomes"

# normalize species into "genus species" form
if [[ "$species" == *"_"* ]]; then
	normalized_species=$(echo "$species" | tr '_' ' ')
	genus_initial=$(echo "$normalized_species" | cut -d' ' -f1 | cut -c1)
	species_part=$(echo "$normalized_species" | cut -d' ' -f2)
else
	normalized_species=$(echo "$species" | tr -d '_')
	genus_initial=$(echo "$normalized_species" | cut -c1)
	species_part=$(echo "$normalized_species" | cut -c2-)
fi

long_name=$(jq --arg gi "$genus_initial" --arg sp "$species_part" -r '
	.search.output.genomes.genome[]
	| select(
			(.long_name | ascii_downcase) as $ln
			| ($ln | split(" ") | length == 2)
			and (($ln | split(" ") | .[0] | startswith($gi | ascii_downcase)))
			and (($ln | split(" ") | .[1]) == ($sp | ascii_downcase))
		)
	| .long_name
' "$sup_genomes")

# get fields (taxon_id, name, short_name)
taxon_id=$(jq --arg ln "$long_name" -r '
	.search.output.genomes.genome[]
	| select(.long_name == $ln)
	| .taxon_id
' "$sup_genomes")

name=$(jq --arg ln "$long_name" -r '
	.search.output.genomes.genome[]
	| select(.long_name == $ln)
	| .name
' "$sup_genomes")

g_short=$(echo "$long_name" | awk '{ print tolower(substr($1, 1, 1)) }')
s_short=$(echo "$long_name" | awk '{ print tolower($2) }')
short_name="${g_short}${s_short}"