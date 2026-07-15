#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <organism_name> <output_file>\n" "$0"
	exit 1
fi

name="$1"	# same organism name as referenced in the field "name" in the panther supported_genomes file
output="$2"	# short species name

# panther datasets annots file
printf "Downloading PANTHER annotations file...\n"
base_url="https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files/"
# find latest release version
latest=$(curl -s "$base_url" | grep -oE "PTHR[0-9]+\.[0-9]+" | head -n 1)
printf "Latest detected version: %s\n" "$latest"
annotations_file="${latest}_${name}"
curl -O "${base_url}${annotations_file}"

# current date
generation_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# metadata header
{
	echo "!PANTHER_Source: https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files/"
	echo "!PANTHER_Release: $latest"
	echo "!Organism: $name"
	echo "!Included_Datasets: PANTHER Pathways, PANTHER GO Slim (BP, MF, CC), PANTHER Protein Class"
	echo "!Generation_Date: $generation_date"
	echo "!Generated_by: auto-Enrich Pipeline"
	echo "!Note: This file contains functional classifications inferred via PANTHER HMMs."
} > "$output"

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
}' "$annotations_file" >> "$output"

