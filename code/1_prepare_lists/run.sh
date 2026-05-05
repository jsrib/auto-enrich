#!/bin/bash
#Prepare lists module 1
cd /opt/1_prepare_lists
set -euo pipefail

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
results_dir="/data/prepared_gene_lists"
rm -rf "$results_dir"
mkdir -p "$results_dir"

if [[ -d "/data/$results_dir" ]]; then
	printf "❌ [MODULE 1] Output directory Error: Output directory 'prepared_gene_lists' found in /data. Please rename or remove it.\n" >&2
	exit 1
fi

if [ ! -f "/data/${input}" ]; then
	printf "❌ [MODULE 1] Configuration Error: Input expression matrix file '%s' not found in set working directory (/data).\n" "${input}" >&2
	exit 1
else
	sed -i 's/\r$//' "/data/${input}"
	input_basename=$(basename "$input")
fi

if [[ -z "$gene" ]]; then
	printf "❌ [MODULE 1] Configuration Error: Variable '%s' is undefined or empty.\n" "$gene" >&2
	exit 1
else
	if ! [[ "$gene" =~ ^[0-9]+$ ]]; then
	echo "❌ [MODULE 1] Column name error: 'gene' must be a numeric column index (starting at 1)." >&2
	exit 1
fi

# verify select pre evaluated genes first
if [[ -n "$selected" ]]; then
	./pre_selected.sh "$config"
	# output: select_genes_list"
	selected_genes="selected_genes_list"
	if [ -f "${selected_genes}" ]; then
		mv "${selected_genes}" "${results_dir}"
		printf "Selected genes saved as: %s in /%s\n" "$selected_genes" "${results_dir}"
		exit 0
	fi
fi

required_vars=("number_groups" "number_samples" "samples" "groups")
for var in "${required_vars[@]}"; do
	if [[ -z "${!var}" ]]; then
		printf "❌ [MODULE 1] Configuration Error: Variable '%s' is undefined or empty.\n" "$var" >&2
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

# calculate averages
if [[ "$calculated_averages" == "true" ]]; then
	output_averages="${input_basename%%.*}_averages.tsv"
	./calculate_averages.sh "$config" "${output_averages}"
	if [ $? -eq 0 ]; then
		printf "Group samples average obtained successfully. Results in: %s\n" "$output_averages"
		cp "$output_averages" /data
		input="${output_averages}"
	fi
fi

# filter isoform
if [[ -z "$isoform" ]]; then
	printf "Skipping isoform filtering.\n"
else
	output_filtered="${input_basename%%.*}_filtered.tsv"
	./isoform_filter.sh "$config" "${input}" "${output_filtered}"
	if [ $? -eq 0 ]; then
		printf "Successfully filtered '%s' based on highest '%s'. Results in: %s\n" "$input" "$isoform" "$output_filtered"
		cp "$output_filtered" /data
		input="${output_filtered}"
	fi
fi

printf "Calculating set conditions using '%s'..." "$input"
output_conditions="${input_basename%%.*}_conditions.tsv"
./calculate_conditions.sh "$config" "${input}"
if [ $? -eq 0 ]; then
	cp "$output_conditions" "${results_dir}"
	printf "Log2 calculations complete. Results in: %s\n" "$output_file"
fi

printf "Evaluating calculated conditions with set thresholds '%s' and '%s'..." "$expression_min" "$expression_max"
output_evaluated="${input_basename%%.*}_evaluated.tsv"
./apply_threshold.sh "$config" "${input}" "${output_evaluated}"
cp "$output_evaluated" /data

for file in *_genes_list; do
	mv "$file" "${results_dir}"
	printf "Prepared genes list saved as: %s in /%s\n" "$file" "${results_dir}"
fi

