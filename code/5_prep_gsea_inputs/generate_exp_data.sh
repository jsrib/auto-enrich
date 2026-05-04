#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config_file>\n" "$0"
	exit 1
fi

source "$1"
output="expression_dataset.gct"

required_vars=("gene" "number_groups" "number_samples" "samples" "groups")

for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        printf "❌ [MODULE 1] Configuration Error: Variable '%s' is undefined or empty.\n" "$var"
        exit 1
    fi
done

# check provided samples with sample number
IFS=',' read -ra sample_cols <<< "$samples"
true_sample_count=${#sample_cols[@]}
if [[ "$number_samples" -ne "$true_sample_count" ]]; then
	printf "❌ [MODULE 1] Sample mismatch error: Expected %s (from 'number_samples' in config), but found %s in 'samples' string.\n" "$number_samples" "$true_sample_count">&2
	exit 1
fi

# check number of samples defined in groups with total number of samples
total_group_samps=$(echo "$groups" | awk '{sum=0; for(i=2; i<=NF; i+=2) sum+=$i; print sum}')
if [[ "$total_group_samps" -ne "$number_samples" ]]; then
	printf "❌ [MODULE 1] Sample mismatch error: Number of group samples (%s in 'groups') is not the same as the total number samples indicated (%s in 'samples').\n" "$total_group_samps" "$number_samples" >&2
	exit 1
fi

# check number of groups
true_group_count=$(echo "$groups" | awk '{print NF/2}')
if [[ "$true_group_count" -ne "$number_groups" ]]; then
	printf "❌ [MODULE 1] Group mismatch error: Number of set groups (%s in 'groups') is not the same as indicated in 'number_groups' (%s).\n" "$true_group_count" "$number_groups" >&2
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
