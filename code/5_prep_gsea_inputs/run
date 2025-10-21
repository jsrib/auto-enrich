#!/bin/bash
# Prepare GSEA inputs Module 5
cd /opt/5_prep_gsea_inputs
set -euo pipefail

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

config="$1"
gsea_dir="/data/gsea/inputs"

if [ ! -f "$config" ]; then
	printf "Error: Config file not found.\n"
	exit 1
else
	sed -i 's/\r$//' "$config"
	source "$config"
fi

if [[ -z "$method" ]]; then
	printf "Error: 'method' not defined in config file.\n"
	exit 1
fi

if [ ! -f "/data/${input}" ]; then
	printf "Error: Input file '%s' not found.\n" "${input}"
	exit 1
fi

# normalize windows /r
sed -i 's/\r$//' "/data/${input}"

# filter isoforms
./process_isoforms.sh "$config"
filtered_isoforms="filtered_isoforms_gsea_${input}"

run_config="run_config"	#runtime config to change input to filtered

if [ -s "$filtered_isoforms" ]; then
	printf "Filtered isoforms of %s. New file: %s\n" "${input}" "${filtered_isoforms}"
	input="${filtered_isoforms}"
	cp "$filtered_isoforms" "/data"

	# update runtime config
	awk -v new_input="$input" '
		BEGIN { updated = 0 }
		/^input=/ {
			print "input=\"" new_input "\""
			updated = 1
			next
		}
		{ print }
		END {
			if (!updated) print "input=\"" new_input "\""
		}
	' "$config" > "$run_config"
else
	printf "No isoforms filtered. Using original file %s.\n" "$input"
	cp "$config" "$run_config"
fi
source "$run_config"

# classic or preranked method input, outputs
case "$method" in
	classic)
		printf "\n➡ Preparing inputs for classic mode...\n"
		./generate_exp_data.sh "$run_config"
		mv expression_dataset.gct "$gsea_dir"
		./generate_phenotype.sh "$run_config"
		mv phenotype_labels.cls "$gsea_dir"
		;;
	preranked)
		printf "\n➡ Preparing ranked list for GSEAPreranked mode...\n"
		./build_preranked_list.sh "$run_config"
		out_dir="$gsea_dir/preranked_lists"
		mkdir -p $out_dir
		mv *.rnk "$out_dir"
		;;
	*)
		printf "Error: Unrecognized method '%s'. Valid options are: classic, preranked.\n" "$method"
		exit 1
		;;
esac