#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config_file>\n" "$0"
	exit 1
fi

config="$1"
output="expression_dataset.gct"

source "$config"

if [[ -z "/data/$input" || -z "$gene" || -z "$samples" || -z "$number_samples" ]]; then
	echo "Error: Config must define input, gene, samples, and number_samples"
	exit 1
else
	sed -i 's/\r$//' "/data/$input"
fi

# read sample cols idxs
IFS=',' read -ra sample_cols <<< "$samples"
actual_sample_count=${#sample_cols[@]}

# valid?
if [[ "$number_samples" -ne "$actual_sample_count" ]]; then
	echo "Error: number_samples=$number_samples but samples= has $actual_sample_count columns" >&2
	exit 1
fi

# num data rows, -header -empty lines
num_data_rows=$(( $(grep -cve '^\s*$' "/data/$input") - 1))

header=$(head -n 1 "/data/$input" | sed $'s/\r//;s/^\xEF\xBB\xBF//')
IFS=$'\t' read -ra cols <<< "$header"

#col idxs array
declare -A col_indices
for i in "${!cols[@]}"; do
	col="${cols[$i]}"
	col_indices["$col"]=$((i + 1))
done

gene_col="${col_indices[$gene]}"
if [[ -z "$gene_col" ]]; then
	printf "Error: Gene column '%s' not found\n" "$gene"
	exit 1
fi

# .gct output format
{
	echo "#1.2"	#first row default
	echo -e "${num_data_rows}\t${number_samples}"	#second row data count

	# third row header: name, description, and sample names
	printf "NAME\tDescription"
	for idx in "${sample_cols[@]}"; do
		col_name="${cols[idx-1]}"
		clean_name=$(echo "$col_name" | sed 's/[^[:alnum:]_]/_/g')
		printf "\t%s" "$clean_name"
	done
	echo ""

	# fifth row data rows
	tail -n +2 "/data/$input" | awk -v FS="\t" -v OFS="\t" \
		-v gene_col="$gene_col" -v desc_col="$description" -v samples="$samples" '
		BEGIN {
			split(samples, sample_idx, ",")
			use_desc = (desc_col != "" && desc_col != "0")
		}
		{
			gene = $gene_col
			desc = use_desc ? $desc_col : "NA"
			printf "%s\t%s", gene, desc
			for (i in sample_idx) {
				printf "\t%s", $(sample_idx[i])
			}
			printf "\n"
		}
	'
} > "$output"

echo "✔ GCT expression file created: $output"
