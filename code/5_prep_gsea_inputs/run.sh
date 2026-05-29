#!/bin/bash
# Prepare GSEA inputs Module 5
cd /opt/5_prep_gsea_inputs
set -euo pipefail

if [ $# -ne 2 ]; then
	printf "Usage: %s <config> <save_dir>\n" "$0"
	exit 1
fi

config="$1"
source "$config"
save_dir="$2"

if [[ -z "$method" ]]; then
	printf "❌ [MODULE 5] Configuration Error: Variable 'method' is undefined or empty. Please specify 'classic' or 'preranked'\n" >&2
	exit 1
else
	case "$method" in
		classic)
			save_dir="${save_dir}/classic_inputs"
			;;
		preranked)
			save_dir="${save_dir}/preranked_lists"
			;;
	esac
fi

rm -r "$save_dir"
mkdir -p "$save_dir"

if [[ -z "$input" ]]; then
	printf "❌ [MODULE 5] Configuration Error: Variable 'input' is undefined or empty. Please specify input file name in the 'config' file.\n" >&2
	exit 1
fi

if [ ! -f "/data/${input}" ]; then
	printf "❌ [MODULE 5] Configuration Error: Input expression matrix file '%s' not found in set working directory (/data).\n" "${input}" >&2
	exit 1
else
	sed -i 's/\r$//' "/data/${input}"
	input_basename=$(basename "$input")
fi

if [[ -z "$gene" ]]; then
	printf "❌ [MODULE 5] Configuration Error: Variable 'gene' is undefined or empty.\n" >&2
	exit 1
else
	if ! [[ "$gene" =~ ^[0-9]+$ ]]; then
	printf "❌ [MODULE 5] Configuration Error: Variable 'gene' must be a numeric column index (starting at 1).\n" >&2
	exit 1
	fi
fi

required_vars=("number_groups" "number_samples" "samples" "groups")
for var in "${required_vars[@]}"; do
	if [[ -z "${!var}" ]]; then
		printf "❌ [MODULE 5] Configuration Error: Variable '%s' is undefined or empty.\n" "$var" >&2
		exit 1
	fi
done

# check provided samples with sample number
IFS=',' read -ra sample_cols <<< "$samples"
true_sample_count=${#sample_cols[@]}
if [[ "$number_samples" -ne "$true_sample_count" ]]; then
	printf "❌ [MODULE 5] Sample mismatch error: Expected %s (from 'number_samples' in config), but found %s in 'samples' string.\n" "$number_samples" "$true_sample_count">&2
	exit 1
fi

# check number of samples defined in groups with total number of samples
total_group_samps=$(echo "$groups" | awk '{sum=0; for(i=2; i<=NF; i+=2) sum+=$i; print sum}')
if [[ "$total_group_samps" -ne "$number_samples" ]]; then
	printf "❌ [MODULE 5] Sample mismatch error: Number of group samples (%s in 'groups') is not the same as the total number samples indicated (%s in 'samples').\n" "$total_group_samps" "$number_samples" >&2
	exit 1
fi

# check number of groups
true_group_count=$(echo "$groups" | awk '{print NF/2}')
if [[ "$true_group_count" -ne "$number_groups" ]]; then
	printf "❌ [MODULE 5] Group mismatch error: Number of set groups (%s in 'groups') is not the same as indicated in 'number_groups' (%s).\n" "$true_group_count" "$number_groups" >&2
	exit 1
fi

# calculate averages if requested
if [[ "$calculate_averages" == "true" ]]; then
	output_averages="${input_basename%%.*}_averages.tsv"
	# check if averages file already exists to avoid unnecessary recalculation
	if [ -f "/data/${output_averages}" ]; then
		printf "Averages file '%s' already exists. Skipping averages calculation step.\n" "${output_averages}"
		input="${output_averages}"
	else
		./calculate_averages.sh "$config" "${output_averages}"
		if [ $? -eq 0 ]; then
			printf "Group samples average obtained successfully. Results in: %s\n" "${output_averages}"
			cp "${output_averages}" /data
			input="${output_averages}"
		fi
	fi
fi

# filter isoform
if [[ -z "$isoform" ]]; then
	printf "Skipping isoform filtering.\n"
else
	output_filtered="${input_basename%%.*}_filtered.tsv"
	# check if filtered file already exists to avoid unnecessary refiltering
	if [ -f "/data/${output_filtered}" ]; then
		printf "Filtered file '%s' already exists. Skipping isoform filtering step.\n" "${output_filtered}"
		input="${output_filtered}"
	else
		./isoform_filter.sh "$config" "${input}" "${output_filtered}"
		if [ $? -eq 0 ]; then
			printf "Successfully filtered '%s' based on highest '%s'. Results in: %s\n" "$input" "$isoform" "${output_filtered}"
			cp "${output_filtered}" /data
			input="${output_filtered}"
		fi
	fi
fi

# classic or preranked method input, outputs
case "$method" in
	classic)
		printf "Preparing inputs for GSEA Classic mode...\n"
		./generate_exp_data.sh "$config" "${input}"
		mv expression_dataset.gct "${save_dir}"
		./generate_phenotype.sh "$config"
		mv phenotype_labels.cls "${save_dir}"
		printf "Results saved in: %s\n" "${save_dir}"
		;;
	preranked)
		printf "Preparing ranked list for GSEAPreranked mode...\n"
		./build_preranked_list.sh "$config" "${input}"
		mv *.rnk "$save_dir"
		printf "Results saved in: %s\n" "${save_dir}"
		;;
	*)
		printf "❌ [MODULE 5] Configuration Error: Unrecognized method '%s'. Valid options are: 'classic' or 'preranked'.\n" "$method"
		exit 1
		;;
esac
