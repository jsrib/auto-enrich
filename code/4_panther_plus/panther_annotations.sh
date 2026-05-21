#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <common_name> <short_species_name>\n" "$0"
	exit 1
fi

common_name="$1"	# same common name as referenced in the field "name" in the panther supported_genomes.json file
output_file="$2"	# output file name

echo "$common_name"

# panther datasets annots file
printf "Downloading and processing PANTHER annotations file ('https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files')\n"
filename="PTHR19.0_${common_name}"
curl -O "https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files/${filename}"

awk -F'\t' '
{
	uniprot = $2;
	symbol = $3;
	
	# Loop through columns 7 to NF
	for (i = 7; i <= NF; i++) {
		n = split($i, parts, ";");
		for (j = 1; j <= n; j++) {
			# split it into name and id using the last # as the separator
			if (match(parts[j], /#([^#]+)$/, arr)) {
				term_id = arr[1];
				# term_name = substr(parts[j], 1, RSTART-1); # optional to keep name
				if (term_id != "") {
					print term_id "\t" uniprot "\t" symbol
				}
			}
		}
	}
}' "$filename" | sort > "${output_file}"

rm "$filename"