#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <ascii_file> <csv_results_file>\n" "$0"
	exit 1
fi

ascii_file="$1"
csv_file="$2"
TEMP_FILE="$(mktemp)"

# add "layer" col
header=$(head -n 1 "$csv_file")
IFS=',' read -r -a header_fields <<< "$header"
new_header="${header_fields[0]},${header_fields[1]},Layer"
for ((k=2; k<${#header_fields[@]}; k++)); do
	new_header+=",${header_fields[k]}"
done
echo "$new_header" > "$TEMP_FILE"

# ascii into array
mapfile -t lines < "$ascii_file"
line_count=${#lines[@]}

for ((i=0; i<line_count; i++)); do
	original_line="${lines[$i]}"
	norm_line=$(echo "$original_line" | sed 's/--/  /g; s/[+|-]/ /g; s/|/ /g')

	# get ID from original line
	ID=$(echo "$original_line" | grep -oE 'R-MMU-[0-9]+')
	[[ -z "$ID" ]] && continue

	# dtermine current indent by count spaces
	indent=$(echo "$norm_line" | sed -E 's/^([ ]*).*/\1/' | awk '{ print length }')

	# calculate depth
	depth=$(( indent / 4 ))	#4 spaces indent = 1 level

	# determine next line indent (or -1 if none)
	if (( i+1 < line_count )); then
		next_norm_line=$(echo "${lines[$((i+1))]}" | sed 's/--/  /g; s/[+|-]/ /g; s/|/ /g')
		next_indent=$(echo "$next_norm_line" | sed -E 's/^([ ]*).*/\1/' | awk '{ print length }')
	else
		next_indent=-1
	fi

	# layers values
	if (( next_indent > indent )); then
		# children > parent
		layer="P${depth}"
	elif (( depth == 0 )); then
		# root parent
		layer="P0"
	else
		# leaf > child
		layer="C"
	fi

	# append matching CSV row
	row=$(grep -m 1 "$ID," "$csv_file")
	if [[ -n "$row" ]]; then
		IFS=',' read -r -a fields <<< "$row"
		# insert layer column as the 3rd (idx 2)
		new_row="${fields[0]},${fields[1]},${layer}"
		for ((j=2; j<${#fields[@]}; j++)); do
			new_row+=",${fields[j]}"
		done
		echo "$new_row" >> "$TEMP_FILE"
	else
		echo "Row empty $row"
	fi
done

# eeplace csv
mv "$TEMP_FILE" "$csv_file"
echo "CSV file '$csv_file' reordered and Layer column added."
