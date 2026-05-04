#!/bin/bash
#Prepare lists module 1
cd /opt/1_prepare_lists
set -euo pipefail

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

source "$1"
results_dir="prepared_gene_lists"
rm -rf "$results_dir"
mkdir -p "$results_dir"

if [[ -d "/data/$results_dir" ]]; then
	printf "❌ [MODULE 1] Error: Output directory /%s found in /data. Please clean or rename.\n" "$results_dir" >&2
	exit 1
fi

if [ ! -f "/data/${input}" ]; then
	printf "❌ [MODULE 1] Configuration Error: Input expression matrix file '%s' not found in set working directory (/data).\n" "${input}" >&2
	exit 1
else
	sed -i 's/\r$//' "/data/${input}"
	basename_ori=$(basename "$input")
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
		printf "Selected genes written to '%s'\n" "$selected_genes"
		cp "${selected_genes}" "${results_dir}"
		mv "${results_dir}" /data
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

# create header mapping
# ./map_config_to_header.sh "$run_config"
# config_map="column_header_mapping.txt"
# mv "$config_map" "${results_dir}"
# printf "\nConfig variables to input file headers mapping saved to %s.\n" "$config_map"

# calculate averages
if [[ "$calculated_averages" == "true" ]]; then
	output_averages="${basename_ori%%.*}_averages.tsv"
	./calculate_averages.sh "$config" "$output_averages"
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
	output_filtered="${basename_ori%%.*}_filtered.tsv"
	./isoform_filter.sh "$config" "${input}" "${output_filtered}"
	if [ $? -eq 0 ]; then
		printf "Successfully filtered '%s' based on highest '%s'. Results in: %s\n" "$input" "$isoform" "$output_filtered"
		cp "$output_filtered" /data
		input="${output_filtered}"
	fi
fi

# calculate conditions
output_conditions="${basename_ori%%.*}_conditions.tsv"
./calculate_conditions.sh "$config" "${input}" "${output_conditions}"
if [ $? -eq 0 ]; then
	cp "$output_conditions" "${results_dir}"
	printf "Log2 calculations complete. Results in: %s\n" "$output_file"
fi


# continue here


# apply thresholds
./apply_threshold.sh "$run_config" "${out_cond}"
rm $out_cond
report="evaluation_report.tsv"
mv $report "${results_dir}"
for file in *_cond*; do
	if [[ "$file" == *.sh ]]; then	# skip calculate_conditions.sh
		continue
	fi
	if [[ "$file" == *_genes_* ]]; then
		printf "Prepared gene lists saved as: %s in /%s\n" "$file" "${results_dir}"
	else
		printf "Selected genes saved as: %s in /%s\n" "$file" "${results_dir}"
	fi
	mv "$file" "${results_dir}"
done
mv "${results_dir}" /data




