#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <organism_name> <short_species_name>\n" "$0"
	exit 1
fi

name="$1"	# same organism name as referenced in the field "name" in the panther supported_genomes file
short="$2"	# short species name

printf "Downloading PANTHER annotations file...\n"
curl -O "https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files/PTHR19.0_${name}"
annotations_file="PTHR19.0_${name}"

if [[ $? -eq 0 && -s "$annotations_file" ]]; then
	printf "Download successful: %s\n" "$annotations_file"
else
	printf "Download failed!\n" >&2
	exit 1
fi

simple_annot="${short}_PTHR19.0_annotations"

awk -F'\t' '
{
	id = $2;
	gene = $3;

	# join col7 (sep ;)
	terms = "";
	for (i = 7; i <= NF; i++) {
		terms = terms $i ";";
	}

	gsub(/\t/, ";", terms);
	gsub(/>/, ";", terms);

	# get between # and next ;
	matches = "";
	while (match(terms, /#[^;]+/)) {
		term = substr(terms, RSTART + 1, RLENGTH - 1);  # Skip the '#' character
		matches = matches term ";";
		terms = substr(terms, RSTART + RLENGTH);
	}

	print id "\t" gene "\t" matches;
}' "$annotations_file" > "$simple_annot"

printf "...processing completed. Processed annotations file saved as %s\n" "$simple_annot"
