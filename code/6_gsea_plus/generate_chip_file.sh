#!/bin/bash
set -euo pipefail

if [ $# -ne 3 ]; then
    printf "Usage: %s <input_file> <output_file> <species_map>\n" "$0"
    exit 1
fi

input_file="$1"
output_file="$2"
species_map="$3"

if [ ! -f "$input_file" ]; then
    printf "❌ [MODULE 6] File Missing: Input file '%s' not found.\n" "$input_file"
    exit 1
fi

if [ ! -s "$species_map" ]; then
    printf "❌ [MODULE 6] File Missing: Species map file '%s' not found.\n" "$species_map"
    exit 1
fi

col_type="symbol"
test_entry=$(awk -F'\t' 'NR==5 {print $1; exit}' "$input_file")
echo $test_entry
if [[ "$test_entry" =~ ^[0-9]+$ ]]; then
    col_type="geneid"
elif [[ "$test_entry" =~ ^[OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2}$ ]]; then
    col_type="uniprot"
fi

if [[ "${col_type}" != "symbol" ]] && [[ "${col_type}" != "geneid" ]] && [[ "${col_type}" != "uniprot" ]]; then
    printf "❌ [MODULE 6] Error: Unknow gene identifier found in '%s'.\n" "$input_file"
    printf "[MODULE 6] Valid identifiers: Entrez GeneIDs, Gene Symbols or UniprotKB IDs.\n"
fi

printf "Detected input gene identifier type: %s\n" "$col_type"

if [[ $col_type == "symbol" ]]; then
    printf "Gene symbols alreayd provided. Skipping chip set file generation and collapse.\n"
else
    printf "Probe Set ID\tGene Symbol\tGene Title\n" > "${output_file}"
    awk -F'\t' -v type="$col_type" '
        NR==FNR {
            if (FNR > 1) {
                gid=$1; uni=$2; sym=$3; name=$4

                # Map GeneID to Row Data
                sym_map[gid] = sym
                name_map[gid] = name
                uni_map[gid] = uni
                
                # Map UniProt to Row Data
                sym_map[uni] = sym
                name_map[uni] = name
                gid_map[uni] = gid
            }
            next
        }
        # process the input by mapping the symbol of uniprot or geneid, using the reference, print NA for missing values
        {
            id = $1
            if (id == "" || id == "Probe Set ID") next
            # check if the ID exists in our map
            if (id in sym_map) {
                probe_id = (type == "uniprot" && id in gid_map) ? id : (id in sym_map ? id : "NA")
                print id "\t" sym_map[id] "\t" name_map[id]
            } else {
                print id "\tNA\tNA"
            }
        }
    ' "$species_map" "$input_file" >> "$output_file"
fi