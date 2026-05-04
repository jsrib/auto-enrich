#!/bin/bash

if [ "$#" -ne 3 ]; then
	printf "Usage: %s <input_ids_file> <mapping_file> <output_file>\n" "$0"
	exit 1
fi

input_file="$1"
map_file="$2"
output_file="$3"

if [ ! -f "$map_file" ]; then
	printf "Error: Mapping file '%s' not found.\n" "$map_file"
	exit 1
fi

> "$output_file"

while IFS= read -r gene_id; do
	grep -P "^${gene_id}\t" "$map_file" >> "$output_file"
done < "$input_file"