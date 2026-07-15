#!/bin/bash
# Mapping info module 2
cd /opt/2_gene_mapping
#set -euo pipefail

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

test_entry=$(awk -F'\t' 'NR==2 {print $1; exit}' "$input_file")

col_type="symbol" # Default
# detect if the input gene ids are geneids, uniprot or symbols based on the format of the second line of the input file (avoid first line as it may contain a header) 
if [[ "$test_entry" =~ ^[0-9]+$ ]]; then
	col_type="geneid"
elif [[ "$test_entry" =~ ^[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}$ ]]; then
	col_type="uniprot"
fi

if [[ "${col_type}" != "symbol" ]] && [[ "${col_type}" != "geneid" ]] && [[ "${col_type}" != "uniprot" ]]; then
	printf "❌ [MODULE 2] Error: Unknow gene identifier found in '%s'." "$input_file"
	printf "Valid identifiers: Entrez GeneIDs, Gene Symbols or UniprotKB IDs."
	exit 1
fi

printf "Detected input gene identifier type: %s\n" "$col_type"

# species ids map file
basename=$(basename "$species_map")
if [ ! -s "$species_map" ]; then
	printf "File '%s' not found, creating new one...\n" "$basename"
	./id_uniprot_symbol_mapping.sh "$taxon" "${species_map}"
	printf "Species ids map file saved under '%s'...\n" "$species_map"
fi

# map input file to uniprot and symbol ids using the species map file (exit 2 if output file already exists, to avoid overwriting)
if [[ ! -f "$output_file" ]]; then
	awk -F'\t' -v type="$col_type" '
		NR==FNR {
			if (FNR > 1) {
				gid=$1; uni=$2; sym=$3

				# anchor key
				key = gid

				# concatenate uniprots (1 or more) for anchor
				seen_key = key "|" uni
				if (!seen[seen_key]++) {
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
		# process the input gene list, mapping to uniprot and symbol using the reference, print NA for missing values
		{
			val = $1
			if (val == "") next 

			if (val in ref) {
				k = ref[val]
				print k "\t" uni_list[k] "\t" final_sym[k]
			} else {
				# if the id is not found in the map, print it in the corresponding column based on the detected type, and NA for the other two columns
				if (type == "geneid")		print val "\tNA\tNA"
				else if (type == "uniprot")	print "NA\t" val "\tNA"
				else						print "NA\tNA\t" val
			}
		}
	' "$species_map" "$input_file" > "$output_file"
fi
