#!/bin/bash

if [ "$#" -ne 2 ]; then
	printf "Usage: %s <input_ids_file> <mapping_file>\n" "$0"
	exit 1
fi

input_file="$1"
map_file="$2"
output_file="unmapped_ids"

> "$output_file"
while IFS= read -r gene_id; do
	# id in map?
	if grep -P "^$gene_id\t" "$map_file" > /dev/null; then
		printf "GeneID %s mapping found.\n" "$gene_id"
	# no? map
	else
		printf "GeneID %s not mapped.\n" "$gene_id"
		printf "%s\n" "$gene_id" >> "$output_file"
	fi
done < "$input_file"

if [ -s "$output_file" ]; then
	printf "Mapping necessary GeneIDs...\n"
else
	printf "All GeneIDs already mapped.\n"
fi