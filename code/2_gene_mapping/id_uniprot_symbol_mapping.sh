#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <taxon_id> <output_name>\n" "$0"
	exit 1
fi

taxon="$1"
output_file="$2"

echo "Downloading UniprotKB to Gene Symbol reference file..."
tmp_file="raw_uniprot_${taxon}"
curl -o "$tmp_file" \
	"https://rest.uniprot.org/uniprotkb/stream?query=organism_id:${taxon}&format=tsv&fields=xref_geneid,accession,gene_primary,protein_name,organism_name"

if [[ ! -s "$tmp_file" ]]; then
	echo "❌ [MODULE 2] Error: Gene mapping file download failed or file is empty." >&2
	exit 1
fi

# process file
printf "Processing and cleaning data...\n"
header="GeneID\tUniProtID\tSymbol\tFullName\tOrganism"
awk -F'\t' -v h="$header" '
BEGIN { print h } 
NR > 1 {
	if ($1 == "") {
			printf "\t%s\t%s\t%s\t%s\n", $2, $3, $4, $5
		} 
		else {
			sub(/;$/, "", $1)
			n = split($1, ids, ";")
			for (i = 1; i <= n; i++) {
				printf "%s\t%s\t%s\t%s\t%s\n", ids[i], $2, $3, $4, $5
			}
		}
}' "$tmp_file" > "unsorted"

# sort file (send empty geneids lines to bottom)
{
	head -n 1 "unsorted"

	# keep all rows, including empty geneIDs rows
	# awk -F'\t' 'NR>1 && $1 != ""' "unsorted" | sort -t$'\t' -k1,1n
	# awk -F'\t' 'NR>1 && $1 == ""' "unsorted"

	# exclude empty geneIDs rows (not references, simplify mapping)
	awk -F'\t' 'NR > 1 && $1 != "" && $1 != "NA" && $1 != "-"' "unsorted" | sort -t$'\t' -k1,1n
	
} > "$output_file"

rm "$tmp_file" "unsorted"