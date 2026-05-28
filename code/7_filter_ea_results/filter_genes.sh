#!/bin/bash

if [ $# -lt 2 ]; then
	printf "Usage: %s <input_file> <excluded_genes_list> <output_file>\n" "$0"
	exit 1
fi

input_file="$1"
excluded_genes="$2"
output_file="${3:-input_filtered_genes}"

if [[ ! -f "$input_file" ]]; then
	printf "Error: File '%s' not found." "$input_file"
	exit 1
fi

if [[ ! -f "$excluded_genes" ]]; then
	printf "Error: File '%s' not found." "$excluded_genes"
	exit 1
fi

# load common genes into array
declare -A common_genes
while read -r count gene; do
	gene=${gene//\'/}	#remove single quotes
	common_genes["$gene"]=1
done < "$excluded_genes"

# determine col idxs
genesym_col=$(head -n 1 "$input_file" | \
awk -F'\t' '
{
for (i=1; i<=NF; i++) {
	gsub(/^ +| +$/, "", $i)
	if ($i == "Genes_in_intersection" || $i == "Genes_in_CoreEnrichment") {
		print i
		exit
	}
}
}')

if [[ -z "$genesym_col" ]]; then
	printf "FILTER GENES Error: Neither 'Genes_in_intersection' nor 'Genes_in_CoreEnrichment' column found in '%s'.\n" "$input_file"
	exit 1
fi

genesym_col=$((genesym_col - 1))

header=$(head -n 1 "$input_file" | tr -d '\r')
IFS=$'\t' read -ra columns <<< "$header"

# process file
{
	echo "$header"

	tail -n +2 "$input_file" | while IFS= read -r line; do
		IFS=$'\t' read -ra cols <<< "$line"

		gene_symbols="${cols[$genesym_col]}"
		IFS=',' read -ra symbols_array <<< "$gene_symbols"

		if [[ $genesym_col -ge 0 ]]; then
			# deal with symbols
			filt_symbols=()
			for sym in "${symbols_array[@]}"; do
				clean_sym="${sym//\'/}"
				clean_sym="${clean_sym// /}"

				[[ -z "$clean_sym" ]] && continue
				if [[ -z "${common_genes[$clean_sym]}" ]]; then
					filt_symbols+=("$sym")
				fi
			done
			if [[ ${#filt_symbols[@]} -eq 0 ]]; then
				continue
			fi
			cols[$((genesym_col))]="${filt_symbols[*]}"
		fi

		# update number of genes if col exists 
		output="${cols[0]}"
		for ((i=1; i<${#cols[@]}; i++)); do
			output+=$'\t'"${cols[$i]}"
		done
		echo "$output"
	done
} > "$output_file"
