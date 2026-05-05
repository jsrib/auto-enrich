#!/bin/bash
#IDs mapping info module 2
cd /opt/2_mapping_info
set -euo pipefail

if [ $# -ne 4 ]; then
	printf "Usage: %s <gene_ids_list> <species_ids_map> <taxon> <output_file>\n" "$0"
	exit 1
fi

input_file="$1"
species_map="$2"
taxon="$3"
output_file="$4"

if [[ ! -s "${input_file}" ]]; then
	printf "❌ [MODULE 2] Input File Missing: Input GeneIDs file '%s' NOT FOUND or EMPTY in 'mapped_gene_lists'.\n" "${input_file}" >&2
	exit 1
fi

# species ids map file
basename=$(basename "$species_map")
if [ -s "$species_map" ]; then
	printf "Species map file found: %s.\n" "$basename"
	printf "Checking for IDs already mapped...\n"
	# awk -F'\t' 'NR==FNR{a[$1];next} !($1 in a)' "$species_map" "${input_file}" > todo_ids
else
	printf "File '%s' not found, creating new one...\n" "$basename"
	./id_uniprot_symbol_mapping.sh "$taxon" "${species_map}"
	printf "Species ids map file saved under '%s'...\n" "$species_map"
fi



## CONTINUE HERE TO HANDLE GENE MAPPING (download file and get corresponding input map files)


# if [[ ! -s todo_ids ]]; then
# 	printf "All IDs already mapped in master file. Skipping API calls.\n"
# else
# 	# 50 ids map at a time (safe gaurd)
# 	mkdir -p chunks
# 	split -l 50 todo_ids chunks/chunk_

# 	total_chunks=$(ls chunks/chunk_* | wc -l)
# 	current=0

# 	for chunk in chunks/chunk_*; do
# 		current=$((current + 1))
# 		printf "[Batch %d/%d] Mapping GeneIDs...\n" "$current" "$total_chunks"

# 		./gene-id-to-symbol.sh "$chunk" tmp_symbols
# 		python3 gene-id-to-uniprotkb "$chunk" tmp_uniprots
# 		# join in master file
# 		awk -F '\t' 'NR==FNR { if (FNR > 1) uniprot[$1] = $2; next }
# 					FNR > 1 && ($1 in uniprot) {
# 						printf "%s\t%s\t%s\t%s\n", $1, uniprot[$1], $2, $3
# 					}' tmp_uniprots tmp_symbols >> "$species_map"

# 		rm tmp_symbols tmp_uniprots "$chunk"
# 	done
# 	rm -rf chunks todo_ids
# fi

# # generate output map file
# printf "Generating specific output file: %s\n" "$output_file"

# if [[ ! -f "$output_file" ]]; then
# 	awk -F'\t' 'NR==FNR{map[$1]=$0; next} ($1 in map){print map[$1]}' "$species_map" "$input_file" > "$output_file"
# else
# 	printf "⚠️ Skipping: Mapped list file '%s' already exists in 'mapped_gene_lists'.\n" "$output_file"
# fi