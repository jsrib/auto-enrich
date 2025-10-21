#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: %s <input_dir>\n" "$0"
	exit 1
fi

input_dir="$1"

if [[ ! -d "$input_dir" ]]; then
	printf "Error: Directory '%s' not found.\n" "$input_dir"
	exit 1
fi

shopt -s nullglob
case "$input_dir" in
	"/data/gprofiler")
		dirs=("$input_dir"/*/results/)
		;;
	"/data/panther")
		dirs=("$input_dir"/*/results/)
		;;
	"/data/gsea")
		dirs=("$input_dir"/results/*/)
		;;
	*)
		printf "Unknown method to generate gene occurrences file.\n"
		exit 1
		;;
esac

for dir in "${dirs[@]}"; do
	input_file="$dir/terms_annotations_results.csv"
	output_file="$dir/gene_occurrences.tsv"
	gene_counts="$dir/gene_counts"

	col_idx=$(head -1 "$input_file" | tr ',' '\n' | grep -nx "Genes_in_list" | cut -d: -f1)

	# count each gene n occurs
	tail -n +2 "$input_file" | \
		cut -d',' -f${col_idx} | \
		tr ' ' '\n' | \
		sed '/^$/d' | \
		sort | \
		uniq -c | \
		awk '{print $2 "\t" $1}' > "$gene_counts"

	# calculate dist
	count_distribution="count_distribution"
	cut -f2 "$gene_counts" | sort | uniq -c | awk '{print $2 "\t" $1}' > "$count_distribution"

	temp_file="$dir/distribution.temp"
	printf "N_Occurrences\tN_Genes\tProportions\tCumulative_Distribution(CDF)\n" > "$temp_file"

	# calculate cumulative dist
	total_genes=$(awk '{sum+=$1} END {print sum}' "$count_distribution")
	sort -n -k1,1 "$count_distribution" | awk -v total="$total_genes" '
	BEGIN { cum_sum = 0 }
	{
		proportion = ($1 / total) * 100
		cum_sum += proportion
		printf "%s\t%s\t%.4f\t%.4f\n", $1, $2, proportion, cum_sum
	}' >> "$temp_file"

	mv "$temp_file" "$output_file"
done
