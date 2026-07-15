#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <ascii_file> <tsv_results_file>\n" "$0"
	exit 1
fi

ascii_file="$1" #txt
tsv_file="$2"
TEMP_FILE="$(mktemp)"

# Read TSV header
header=$(head -n 1 "$tsv_file")

# add "depth" column
new_header="${header}\tdepth"
echo -e "$new_header" > "$TEMP_FILE"

# ascii into array
mapfile -t lines < "$ascii_file"
line_count=${#lines[@]}

for ((i=0; i<line_count; i++)); do
	original_line="${lines[$i]}"

	# normalize ASCII structure line
	norm_line=$(echo "$original_line" | sed 's/--/  /g; s/[+|-]/ /g; s/|/ /g')

	# extract ID
	ID=$(echo "$original_line" | grep -oE 'R-[A-Z]{3}-[0-9]+')
	[[ -z "$ID" ]] && continue

	# compute indentation (spaces at beginning)
	indent=$(echo "$norm_line" | sed -E 's/^([ ]*).*/\1/' | awk '{ print length }')

	# depth = 4 spaces per level
	depth=$(( indent / 4 ))

	# fetch matching TSV row
	row=$(grep -m 1 "$ID"$'\t' "$tsv_file")
	if [[ -n "$row" ]]; then
		# append depth as last column (TSV)
		echo -e "${row}\t${depth}" >> "$TEMP_FILE"
	else
		echo "Warning: missing row for $ID" >&2
	fi
done

# replace original TSV
mv "$TEMP_FILE" "$tsv_file"

echo "TSV file '$tsv_file' updated with depth column."