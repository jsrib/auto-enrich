#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <common_name> <short_species_name>\n" "$0"
	exit 1
fi

common_name="$1"	# same common name as referenced in the field "name" in the panther supported_genomes.json file
output_file="$2"	# short species name

# panther datasets annots file
printf "Downloading and processing PANTHER annotations file ('https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files')\n"
curl -O "https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files/PTHR19.0_${common_name}"
annotations_file="PTHR19.0_${common_name}"

if [[ $? -eq 0 && -s "$annotations_file" ]]; then
	printf "Download successful: %s\n" "$annotations_file"
else
	printf "Download failed!\n" >&2
	exit 1
fi

awk -F'\t' '
{
	id = $2;
	gene = $3;

	# join columns >7 into string ; separated
	terms = "";
	for (i = 7; i <= NF; i++) {
		terms = terms $i ";";
	}

	# normalize
	gsub(/\t/, ";", terms);
	gsub(/>/, ";", terms);

	# get substrings between # and next ;
	matches = "";
	while (match(terms, /#[^;]+/)) {
		term = substr(terms, RSTART + 1, RLENGTH - 1);  # Skip the '#' character
		matches = matches term ";";
		terms = substr(terms, RSTART + RLENGTH);
	}

	print id "\t" gene "\t" matches;
}' "$annotations_file" > "$output_file"

rm -r "$annotations_file"