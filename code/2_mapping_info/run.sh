#!/bin/bash
#IDs mapping info module 2
cd /opt/2_mapping_info
set -euo pipefail

if [ $# -ne 3 ]; then
	printf "Usage: %s <gene_ids_list_file> <species> <output_file_name>\n" "$0"
	exit 1
fi

input_file="$1"
species_short="$2"
output_file="$3"

if [ ! -f "/data/${input_file}" ]; then
	printf "Error: Input file %s not found.\n" "${input_file}"
	exit 1
fi

# species ids map file
map_file_path="/data/${species_short}_ids_map"
if [ -f "$map_file_path" ]; then
	printf "Map file for %s found: %s.\n" "$species_short" "$map_file_path"
else
	printf "File '%s' not found, creating new one...\n" "$map_file_path"
	printf "GeneID\tUniprotID\tGeneSymbol\tFullName\n" > "$map_file_path"
fi

./check_mapped_ids.sh "/data/${input_file}" "$map_file_path" # Output: unmapped_ids
if [[ -f "unmapped_ids" ]] && [[ -s "unmapped_ids" ]]; then
	printf "Mapping Gene Symbol and UniprotKB IDs unmapped GeneIDs in '%s'...\n" "${input_file}"
	./gene-id-to-symbol.sh unmapped_ids 	#output: gene_symbols
	printf "\nNow mapping UniprotKB IDs\n"
	./gene-id-to-uniprotkb unmapped_ids new_uniprots	#output: new_uniprots
	# merge ids, unis, symbols and name
	awk -F '\t' 'NR==FNR { if (FNR > 1) uniprot[$1] = $2; next }
				 FNR > 1 && ($1 in uniprot) {
					 printf "%s\t%s\t%s\t%s\n", $1, uniprot[$1], $2, $3
				 }' new_uniprots gene_symbols >> "$map_file_path"
fi

./map_input_ids.sh "/data/${input_file}" "$map_file_path" "${output_file}"
mv "${output_file}" /data

printf "Mapping complete. Saved into %s.\n" "$map_file_path"