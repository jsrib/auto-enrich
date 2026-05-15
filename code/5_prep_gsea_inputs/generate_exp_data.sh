#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
	printf "Usage: %s <config> <input>\n" "$0"
	exit 1
fi

source "$1"
input_file="/data/$2" # possible new input if averages preivous calculated or isoform filtered
output="expression_dataset.gct"

if [ ! -f "${input_file}" ]; then
	printf "❌ [MODULE 5] Input File Missing: Input expression matrix file '%s' not found for GSEA Classic inputs generation.\n" "${input_file}" >&2
	exit 1	
fi

required_vars=("gene" "number_groups" "number_samples" "samples" "groups")
for var in "${required_vars[@]}"; do
	if [[ -z "${!var}" ]]; then
		printf "❌ [MODULE 5] Configuration Error: Variable '%s' is undefined or empty.\n" "$var"
		exit 1
	fi
done

# num data rows, -header -empty lines
num_data_rows=$(( $(grep -cve '^\s*$' "$input_file") - 1))

header=$(head -n 1 "$input_file" | sed $'s/\r//;s/^\xEF\xBB\xBF//')
IFS=$'\t' read -ra cols <<< "$header"

#col idxs array
declare -A col_indices
for i in "${!cols[@]}"; do
	col="${cols[$i]}"
	col_indices["$col"]=$((i + 1))
done

IFS=',' read -ra sample_indices <<< "$samples"

# .gct output format spec: https://docs.gsea-msigdb.org/#GSEA/GSEA_User_Guide/#preparing-data-files-for-gsea
{
	echo "#1.2"	#first row default
	echo -e "${num_data_rows}\t${number_samples}"	#second row data count

	# third row header: name, description, and sample names
	printf "NAME\tDescription"
	for idx in "${sample_indices[@]}"; do
		col_name="${cols[idx-1]}"
		clean_name=$(echo "$col_name" | sed 's/[^[:alnum:]_]/_/g')
		printf "\t%s" "$clean_name"
	done
	echo ""

	# fifth row data rows
	tail -n +2 "$input_file" | awk -v FS="\t" -v OFS="\t" \
		-v gene_col="$gene" -v desc_col="$description" -v samples="$samples" '
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

echo "GCT expression file created: $output"
