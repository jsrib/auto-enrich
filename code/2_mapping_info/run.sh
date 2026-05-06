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
	printf "❌ [MODULE 2] Input File Missing: Input genes file '%s' NOT FOUND or EMPTY in 'prepared_gene_lists'.\n" "${input_file}" >&2
	exit 1
fi

# remove empty rows
sed -i 's/\r//g; /^[[:space:]]*$/d' "${input_file}"

if [[ ! -s "${input_file}" ]]; then
	printf "❌ [MODULE 2] Input File Empty: '%s' has no valid genes after cleaning.\n" "${input_file}" >&2
	exit 1
fi

# species ids map file
basename=$(basename "$species_map")
if [ ! -s "$species_map" ]; then
	printf "File '%s' not found, creating new one...\n" "$basename"
	./id_uniprot_symbol_mapping.sh "$taxon" "${species_map}"
	printf "Species ids map file saved under '%s'...\n" "$species_map"
fi

# generate output map file
if [[ ! -f "$output_file" ]]; then
	awk -F'\t' '
		NR==FNR {
			if (FNR > 1) {
				gid=$1; uni=$2; sym=$3

				# anchor reference
				key = gid

				# concatenate uniprots (1 or more) for anchor
				if (!seen[key, uni]++) {
					uni_list[key] = (uni_list[key] == "" ? "" : uni_list[key] ",") uni
				}

				final_sym[key] = sym

				# map identifiers to anchor (geneid)
				ref[gid] = key
				ref[uni] = key
				ref[sym] = key
			}
			next
		}

		{
			val = $1
			if (val in ref) {
				k = ref[val]
				print k "\t" uni_list[k] "\t" final_sym[k]
			} else {
				print val "\tNA\tNA"
			}
		}
	' "$species_map" "$input_file" > "$output_file"
else
	printf "⚠️ Skipping: Mapped list file '%s' already exists in 'mapped_gene_lists'.\n" "$output_file"
fi
