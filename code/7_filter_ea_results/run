#!/bin/bash
# Filter EA results Module 7
cd /opt/7_filter_ea_results
set -euo pipefail

if [ $# -lt 2 ]; then
	printf "Usage: %s <results_directory> [--max-annotations N] [--max-occurrence N] [--min-ratio N]\n" "$0"
	exit 1
fi

input_dir="$1"
shift # shift to parse optional arguments

if [[ ! -d "/data/$input_dir" ]]; then
	printf "Error: '%s' is not a valid directory.\n" "$input_dir"
	exit 1
fi

max_annot=""
max_occr=""
min_ratio=""

# print usage
print_usage() {
	printf "\nUsage: %s [--max-annotations N] [--max-occurrence N] [--min-ratio N]\n" "$(basename "$0")"
	printf "Options:\n"
	printf "  --max-annotations N   Filter out terms with more than N annotated genes (column: TermCount)\n"
	printf "  --max-occurrence N    Filter out genes occurring in more than N terms (used in exclusion step)\n"
	printf "  --min-ratio N         Keep only terms with enrichment ratio >= N (column: Ratio(%%))\n"
	printf "\n"
}

# parse arguments
while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
		--max-annotations)
			max_annot="$2"
			shift 2
			;;
		--max-occurrence)
			max_occr="$2"
			shift 2
			;;
		--min-ratio)
			min_ratio="$2"
			shift 2
			;;
		--help|-h)
			print_usage
			exit 0
			;;
		*)
			printf "Error: Unknown argument: %s\n" "$1"
			print_usage
			exit 1
			;;
	esac
done

# at least one filter?
if [[ -z "$max_annot" && -z "$max_occr" && -z "$min_ratio" ]]; then
	printf "Error: At least one filter (--max-annotations, --max-occurrence, --min-ratio) must be set.\n"
	exit 1
fi

base_data="/data/${input_dir}/terms_annotations_results.csv"
data_lines=$(tail -n +2 "$base_data" | wc -l)
final_output="terms_annotations_filtered.csv"

# step 1: priority to max-occr (if set)
if [[ -n "$max_occr" ]]; then
	printf "Applying --max-occurrence cutoff: %s\n" "$max_occr"
	./common_genes.sh "/data/${input_dir}" "$max_occr" || exit 1
	./filter_genes.sh "/data/${input_dir}" || exit 1
	input_file="filtered_genes"
else
	input_file="$base_data"
fi

# step 2: apply other filters
if [[ -n "$max_annot" || -n "$min_ratio" ]]; then
	[[ -n "$max_annot" ]] && printf "Applying --max-annotations cutoff: %s\n" "$max_annot"
	[[ -n "$min_ratio" ]] && printf "Applying --min-ratio cutoff: %s\n" "$min_ratio"

	header=$(head -n 1 "$input_file")
	IFS=',' read -ra columns <<< "$header"

	# get required cols to filter (termcount and ratio)
	termcount_idx=""
	ratio_idx=""
	for i in "${!columns[@]}"; do
		if [[ "${columns[$i]}" == "TermCount" ]]; then
			termcount_idx=$((i + 1))
		elif [[ "${columns[$i]}" == "Ratio(%)" ]]; then
			ratio_idx=$((i + 1))
		fi
	done
	if [[ -z "$termcount_idx" || -z "$ratio_idx" ]]; then
		echo "Error: Required columns 'TermCount' and/or 'Ratio(%)' not found in header."
		exit 1
	fi

	# Run awk with dynamic column positions
	awk -F',' \
		-v max_annot="$max_annot" \
		-v min_ratio="$min_ratio" \
		-v termcount="$termcount_idx" \
		-v ratio="$ratio_idx" '
	BEGIN { OFS = FS }	#output separator same as input
	NR == 1 { print; next }
	{
		annot_pass = (max_annot == "" || $termcount <= max_annot)	#filter empty pass, otherwise act
		ratio_val = $ratio + 0
		ratio_pass = (min_ratio == "" || ratio_val >= min_ratio) && ratio_val > 0	#filter empty pass, otherwise act
		if (annot_pass && ratio_pass)
			print
	}
	' "$input_file" > "$final_output"
else
	cp "$input_file" "$final_output"
fi

remain_lines=$(tail -n +2 "$final_output" | wc -l)

if [[ "$remain_lines" -eq 0 ]]; then
	printf "⚠️ No data remains after filtering.\n"
	rm -f "$final_output"
	exit 0
else
	printf "Initial %d entries reduced to %d entries. Output saved to /data/%s/%s\n" "$data_lines" "$remain_lines" "$input_dir" "$final_output"
	mv "$final_output" "/data/${input_dir}/"
fi