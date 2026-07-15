#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

config="$1"
output="phenotype_labels.cls"

source "$config"

required_vars=("number_groups" "number_samples" "samples" "groups")
for var in "${required_vars[@]}"; do
	if [[ -z "${!var}" ]]; then
		printf "❌ [MODULE 5] Configuration Error: Variable '%s' is undefined or empty.\n" "$var" >&2
		exit 1
	fi
done

if [[ "$number_groups" -gt 2 ]]; then
	printf "❌ [MODULE 5] Configuration Error: 'number_groups' is %s. GSEA Classic mode in this pipeline only supports a maximum of 2 groups.\n" "$number_groups" >&2
	exit 1
fi

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

# parse and validate pairs
read -ra items <<< "$groups"
if (( ${#items[@]} % 2 != 0 )); then
	printf "❌ [MODULE 5] Configuration Error: groups must have pairs of <group_name> <count>\n" >&2
	exit 1
fi

class_labels=()
group_names=()

for ((i=0; i<${#items[@]}; i+=2)); do
	group="${items[i]}"
	count="${items[i+1]}"

	if ! [[ "$count" =~ ^[0-9]+$ ]]; then
		printf "❌ [MODULE 5] Configuration Error: Invalid count '%s' for group '%s'\n" "$count" "$group" >&2
		exit 1
	fi

	class_labels+=($(yes "$group" | head -n "$count"))

	# track unique group names
	if [[ ! " ${group_names[*]} " =~ " $group " ]]; then
		group_names+=("$group")
	fi
done

# generate output
{
	printf "%d %d 1\n" "$number_samples" "${#group_names[@]}"
	printf "# %s\n" "${group_names[*]}"
	printf "%s " "${class_labels[@]}"
	printf "\n"
} > "$output"

printf "Phenotype Labels CLS file created at: %s\n" "$output"