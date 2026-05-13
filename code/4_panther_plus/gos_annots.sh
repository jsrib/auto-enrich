#!/bin/bash

if [ $# -ne 4 ]; then
	printf "Usage: %s <species_taxon> <go_term> <term_dir> <go_cache_file>\n" "$0"
	exit 1
fi

species_taxon="$1"
go_term="$2"
term_dir="$3"
go_cache_file="$4"

mkdir -p "$term_dir"

if [ ! -f "${go_cache_file}" ]; then
    touch "$go_cache_file"
fi

go_term_encoder="${go_term/:/%3A}"
taxon_encoder="${species_taxon// /%20}"

output_file=$(mktemp)
genes_file="${term_dir}/genes_in_term"

# check cache first
if term_genes=$(grep -P "^${go_term}\t" "$go_cache_file" 2>/dev/null); then
    printf "Found %s in cache.\n" "$go_term"
    echo "$term_genes" | cut -f2- | tr ' ' '\n' | sort -u > "$genes_file"
    exit 0
fi

# fetch go terms from GOlr auxiliary API
printf "Fetching %s from GOlr...\n" "$go_term"
curl -s "https://golr-aux.geneontology.io/solr/select?defType=edismax&qt=standard&indent=on&wt=csv&rows=100000&start=0&fl=bioentity_label&facet=false&fq=document_category:%22annotation%22&fq=isa_partof_closure:%22$go_term_encoder%22&fq=taxon_subset_closure_label:%22$taxon_encoder%22&q=*%3A*" -o "$output_file"

# Solr wt=csv uses commas and often double quotes values
if [[ $(wc -l < "$output_file") -gt 1 ]]; then
	awk -F',' 'NR > 1 {
		gsub(/^"|"$/, "", $1); # strip double quotes from the label
		if ($1 != "" && !seen[$1]++) { print $1 }
	}' "$output_file" > "$genes_file"
	
	# update cache with space-separated genes
	genes_joined=$(paste -sd' ' "$genes_file")
	echo -e "${go_term}\t${genes_joined}" >> "$go_cache_file"
	printf "Successfully processed %s\n" "$go_term"
else
	printf "⚠️  Warning: GO term '%s' returned no results. It may be obsolete or the taxon is wrong.\n" "$go_term"
	: > "$genes_file"
fi

rm -f "$output_file"

sleep 10