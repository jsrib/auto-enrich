#!/bin/bash
# uniprot to symbol reference file

if [ $# -ne 2 ]; then
	printf "Usage: %s <short_name> <taxon_id>\n" "$0"
	exit 1
fi

short_name="$1"
taxon="$2"

echo  "Downloading UniprotKB to Gene Symbol reference file..."
uniprot_gene_file="${short_name}_gene_uniprot"
curl -o "$uniprot_gene_file" \
	"https://rest.uniprot.org/uniprotkb/stream?query=organism_id:${taxon}&format=tsv&fields=accession,gene_primary,protein_name,organism_name"