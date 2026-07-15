#!/bin/bash
# Filter EA results Module 7
cd /opt/7_filter_ea_results
<<<<<<< HEAD
#set -euo pipefail

if [ $# -lt 2 ]; then
	printf "Usage: %s <results_directory> [--max-annotations N] [--max-occurrence N] [--min-coverage N]\n" "$0"
=======
set -euo pipefail

if [ $# -lt 2 ]; then
	printf "Usage: %s <results_directory> [--max-annotations N] [--max-occurrence N] [--min-ratio N]\n" "$0"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
	exit 1
fi

input_dir="$1"
<<<<<<< HEAD
shift

if [[ ! -d "$input_dir" ]]; then
=======
shift # shift to parse optional arguments

if [[ ! -d "/data/$input_dir" ]]; then
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
	printf "Error: '%s' is not a valid directory.\n" "$input_dir"
	exit 1
fi

max_annot=""
max_occr=""
<<<<<<< HEAD
min_coverage=""

print_usage() {
	printf "\nUsage: %s [--max-annotations N] [--max-occurrence N] [--min-coverage N]\n" "$(basename "$0")"
	printf "Options:\n"
	printf "  --max-annotations N   Filter out terms with more than N annotated genes (column: TermCount)\n"
	printf "  --max-occurrence N    Filter out genes occurring in more than N terms (used in exclusion step)\n"
	printf "  --min-coverage N         Keep only terms with enrichment coverage >= N (column: coverage(%%))\n"
=======
min_ratio=""

# print usage
print_usage() {
	printf "\nUsage: %s [--max-annotations N] [--max-occurrence N] [--min-ratio N]\n" "$(basename "$0")"
	printf "Options:\n"
	printf "  --max-annotations N   Filter out terms with more than N annotated genes (column: TermCount)\n"
	printf "  --max-occurrence N    Filter out genes occurring in more than N terms (used in exclusion step)\n"
	printf "  --min-ratio N         Keep only terms with enrichment ratio >= N (column: Ratio(%%))\n"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
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
<<<<<<< HEAD
		--min-coverage)
			min_coverage="$2"
=======
		--min-ratio)
			min_ratio="$2"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
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
<<<<<<< HEAD
if [[ -z "$max_annot" && -z "$max_occr" && -z "$min_coverage" ]]; then
	printf "Error: At least one filter (--max-annotations, --max-occurrence, --min-coverage) must be set.\n"
	exit 1
fi

# filter enriched terms annotations file
for input_file in "${input_dir}"/enriched_terms_annotations*.tsv; do
	[ -f "$input_file" ] || continue
	base_name=$(basename "$input_file")
	data_lines=$(tail -n +2 "$input_file" | wc -l)
	final_output="filtered_${base_name}"

	working_file="$input_file"

	# step 1: priority to max-occr (if set)
	if [[ -n "$max_occr" ]]; then
		printf "Applying --max-occurrence cutoff: %s\n" "$max_occr"
		./gene_occurrences.sh "${input_file}" "$max_occr" "excluded_genes_list" || exit 1
		./filter_genes.sh "${input_file}" "excluded_genes_list" "input_filtered_genes" || exit 1
		working_file="input_filtered_genes"
		cp "excluded_genes_list" "${input_dir}/excluded_genes_after_filtering"
		cp "input_filtered_genes" "${input_dir}"
	fi

	# step 2: apply other filters
	if [[ -n "$max_annot" || -n "$min_coverage" ]]; then
		[[ -n "$max_annot" ]] && printf "Applying --max-annotations cutoff: %s\n" "$max_annot"
		[[ -n "$min_coverage" ]] && printf "Applying --min-coverage cutoff: %s\n" "$min_coverage"

		header=$(head -n 1 "$working_file" | tr -d '\r')
		IFS=$'\t' read -ra columns <<< "$header"

		# get required cols to filter (termcount and coverage - changed to coverage)
		termcount_idx=""
		coverage_idx=""
		for i in "${!columns[@]}"; do
			if [[ "${columns[$i]}" == "TermSize" ]]; then
				termcount_idx=$((i + 1))
			elif [[ "${columns[$i]}" == "Coverage" ]]; then
				coverage_idx=$((i + 1))
			fi
		done
		if [[ -z "$termcount_idx" || -z "$coverage_idx" ]]; then
			echo "Error: Required columns 'TermSize' and/or 'Coverage' not found in header."
			exit 1
		fi

		# Run awk with dynamic column positions
		awk -F'\t' \
			-v max_annot="$max_annot" \
			-v min_coverage="$min_coverage" \
			-v termcount="$termcount_idx" \
			-v coverage="$coverage_idx" '
		BEGIN { OFS = FS }	#output separator same as input
		NR == 1 { print; next }
		{
			annot_pass = (max_annot == "" || $termcount <= max_annot)	#filter empty pass, otherwise act
			coverage_val = $coverage + 0
			coverage_pass = (min_coverage == "" || coverage_val >= min_coverage) && coverage_val > 0	#filter empty pass, otherwise act
			if (annot_pass && coverage_pass)
				print
		}
		' "$working_file" > "$final_output"
	else
		cp "$input_file" "$final_output"
	fi

	remain_lines=$(tail -n +2 "$final_output" | wc -l)

	if [[ "$remain_lines" -eq 0 ]]; then
		printf "No data remains after filtering.\n"
		mv "$final_output" "${input_dir}/"
		exit 2
	else
		printf "Initial %d entries reduced to %d entries. Output saved to %s/%s\n" "$data_lines" "$remain_lines" "$input_dir" "$final_output"
		cp "$final_output" "${input_dir}/"
	fi
done

# filter enrichment fields file
fields_to_filter="$input_dir/enrichment_fields.tsv"
base_fields=$(basename "$fields_to_filter")
output_fields="filtered_${base_fields}"

if [[ -f "$fields_to_filter" && -f "$final_output" ]]; then
	awk -F'\t' -v OFS='\t' '
	NR == FNR {
		if (FNR > 1) allowed[$1] = 1
		next
	}
	FNR == 1 {
		print
		next
	}
	{
		if ($1 in allowed)
			print
	}
	' "$final_output" "$fields_to_filter" > "$output_fields"
	cp "$output_fields" "${input_dir}/"
else
    echo "Missing enrichment_fields.tsv or final_output file"
fi
=======
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
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
