#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <results_directory>\n" "$0"
	exit 1
fi

input_dir="$1"
input_file="${input_dir}/terms_annotations_results.csv"
excluded_genes="${input_dir}/excluded_genes"
output_file="filtered_genes"

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

header_line=$(head -n 1 "$input_file")
IFS=',' read -ra headers <<< "$header_line"

# determine col idxs
geneids_col=-1
genesym_col=-1

for i in "${!headers[@]}"; do
	if [[ "${headers[$i]}" == "GeneIDs_in_list" ]]; then
		geneids_col=$i
	elif [[ "${headers[$i]}" == "Genes_in_list" ]]; then
		genesym_col=$i
	fi
done

if [[ $genesym_col -eq -1 ]]; then
	printf "Error: Column 'Genes_in_list' not found.\n"
	exit 1
fi

# process file
{
	echo "$header_line"

	tail -n +2 "$input_file" | while IFS= read -r line; do
		IFS=',' read -ra cols <<< "$line"

		gene_symbols="${cols[$genesym_col]}"
		IFS=' ' read -ra symbols_array <<< "$gene_symbols"

		if [[ $geneids_col -ge 0 ]]; then
			gene_ids="${cols[$geneids_col]}"
			IFS=' ' read -ra ids_arr <<< "$gene_ids"

			# #ids = #arrays?
			if [[ ${#ids_arr[@]} -ne ${#symbols_array[@]} ]]; then
				continue
			fi

			filt_ids=()
			filt_symbols=()

			# filter out common genes
			for i in "${!ids_arr[@]}"; do
				clean_id="${ids_arr[$i]//\'/}"	#remove single quotes
				if [[ -z "${common_genes[$clean_id]}" ]]; then
					filt_ids+=("'$clean_id'")
					filt_symbols+=("${symbols_array[$i]}")
				fi
			done

			# no ids left, skip line
			if [[ ${#filt_ids[@]} -eq 0 ]]; then
				continue
			fi

			# reconstruct row
			cols[$((geneids_col))]="${filt_ids[*]}"
			cols[$((genesym_col))]="${filt_symbols[*]}"

		else
			# deal with symbols
			filt_symbols=()
			for sym in "${symbols_array[@]}"; do
				clean_sym="${sym//\'/}"
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
			output+=",""${cols[$i]}"
		done
		echo "$output"
	done
} > "$output_file"

printf "Filtered genes saved to: %s\n" "$output_file"