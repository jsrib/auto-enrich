#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <config_file>\n" "$0"
	exit 1
fi

config="$1"
output="phenotype_labels.cls"

source "$config"

for var in samples number_samples number_groups group_order; do
	if [[ -z "${!var}" ]]; then
		printf "Error: '%s' variable not set in config.\n" "$var" >&2
		exit 1
	fi
done

# vars comma-sep list
IFS=',' read -ra sample_cols <<< "$samples"
actual_sample_count=${#sample_cols[@]}

# number_samples matches count
if [[ "$number_samples" -ne "$actual_sample_count" ]]; then
	printf "Error: number_samples (%d) does not match count of samples (%d) in 'samples'.\n" "$number_samples" "$actual_sample_count" >&2
	exit 1
fi

# parse and validate pairs
read -ra items <<< "$group_order"
if (( ${#items[@]} % 2 != 0 )); then
	printf "Error: group_order must have pairs of <group_name> <count>\n" >&2
	exit 1
fi

total_group_samples=0
class_labels=()
group_names=()

for ((i=0; i<${#items[@]}; i+=2)); do
	group="${items[i]}"
	count="${items[i+1]}"

	if ! [[ "$count" =~ ^[0-9]+$ ]]; then
		printf "Error: Invalid count '%s' for group '%s'\n" "$count" "$group" >&2
		exit 1
	fi

	total_group_samples=$((total_group_samples + count))
	class_labels+=($(yes "$group" | head -n "$count"))

	# track unique group names
	if [[ ! " ${group_names[*]} " =~ " $group " ]]; then
		group_names+=("$group")
	fi
done

# total samples from group_order matches number_samples
if [[ "$total_group_samples" -ne "$number_samples" ]]; then
	printf "Error: Sum of counts in group_order (%d) does not match number_samples (%d)\n" "$total_group_samples" "$number_samples" >&2
	exit 1
fi

# generate output
printf "%d %d 1\n" "$number_samples" "${#group_names[@]}" > "$output"
printf "# %s\n" "${group_names[*]}" >> "$output"
printf "%s " "${class_labels[@]}" >> "$output"
printf "\n" >> "$output"

printf "✔ Phenotype Labels CLS file created at: %s\n" "$output"