#!/bin/bash
set -x

if [ $# -ne 2 ]; then
	printf "Usage: %s <common_name> <output_file>\n" "$0"
	exit 1
fi

common_name="$1"	# same common name as referenced in the field "name" in the panther supported_genomes.json file
output_file="$2"	# output file name

# panther datasets annots file
printf "Downloading and processing PANTHER annotations file ('https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files')\n"
filename="PTHR19.0_${common_name}"
curl -O "https://data.pantherdb.org/ftp/sequence_classifications/current_release/PANTHER_Sequence_Classification_files/${filename}"

awk -F'\t' '
	$1 ~ /^(Pathway|Biological|Molecular|#)/ {next}
	{
		uniprot = $2;
		symbol = $3;

		for (i = 7; i <= NF; i++) {
			n = split($i, parts, ";");
			for (j = 1; j <= n; j++) {
				count = split(parts[j], ids, "#");
				if (count > 1) {
					term_id = ids[count];
					if (term_id != "") {
						print term_id "\t" uniprot "\t" symbol
					}
				}
			}
		}
	}
' "$filename" | sort -u > "${output_file}"

rm "$filename"