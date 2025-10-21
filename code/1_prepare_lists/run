#!/bin/bash
#Prepare lists module 1
cd /opt/1_prepare_lists
set -euo pipefail

if [ $# -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

config="$1"
results_dir="prepared_gene_lists"
rm -rf "$results_dir"
mkdir -p "$results_dir"

if [[ -d "/data/$results_dir" ]]; then
	printf "Error: Output directory /%s already exists in /data. Clean or rename.\n" "$results_dir"
	exit 1
fi

if [ ! -f "$config" ]; then
	printf "Error: config file not found.\n"
	exit 1
else
	sed -i 's/\r$//' "$config"
	source "${config}"
fi

if [ ! -f "/data/${input}" ]; then
	printf "Error: Input file '%s' not found.\n" "${input}"
	exit 1
else
	sed -i 's/\r$//' "/data/${input}"
fi

# verify select pre evaluated genes first
./pre_evaluated.sh "${config}"	# output: select_genes_list"
selected_genes="selected_genes_list"
if [ -f "${selected_genes}" ]; then
	printf "\nSelected genes written to %s\n" "$selected_genes"
	cp "${selected_genes}" "${results_dir}"
	mv "${results_dir}" /data
	exit 0
else
	printf "\nNo selection column ('select') specified in config. Skipping gene selection.\n"
fi

# filter isoform
./filter_isoforms_avg.sh "${config}"
filtered_isoforms="filtered_${input}"

run_config="run_config"	#runtime config to change input to filtered

if [ -s "$filtered_isoforms" ]; then
	printf "Filtered isoforms of %s. New file: %s\n" "${input}" "${filtered_isoforms}"
	input="${filtered_isoforms}"
	cp "$filtered_isoforms" "/data"

	# updated config runtime
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

# create header mapping
./map_config_to_header.sh "$run_config"
config_map="column_header_mapping.txt"
mv "$config_map" "${results_dir}"
printf "\nConfig variables to input file headers mapping saved to %s.\n" "$config_map"

# calculate or assign averages
./calculate_averages.sh "$run_config"
out_avg="output_averages"
printf "Averages obtained successfully.\n\n"

# calculate conditions
./calculate_conditions.sh "$run_config" "${out_avg}"
out_cond="output_conditions"
printf "Conditions calculated successfully.\n\n"

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
