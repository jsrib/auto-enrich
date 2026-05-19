#!/bin/bash

if [ $# -ne 8 ]; then
	printf "Usage: %s <input_map_file> <results_file> <species_taxon> <save_dir> <panther_annotations> <reac_annotations> <go_annotations> <gene_map>\n" "$0"
	exit 1
fi

input_list="$1"
enriched_fields_file="$2"
species_taxon="$3"	
save_dir="$4"
panther_annot="$5"
reac_annot="$6"
go_annot="$7"
gene_map="$8"	# species gene map file (geneid, uniprot, symbol)
output_file="enriched_terms_annotations.tsv"

for file in "$panther_annot" "$reac_annot" "$gene_map"; do
	if [ ! -f "$file" ]; then
		printf "❌ [MODULE 4] Error: Annotations/mapping file not found '%s'.\n" "$file"
		exit 1
	fi
done

printf "TermID\tName\tSource\tCoverage\tIntersectionSize\tGenes_in_intersection\tTermSize\tGenes_in_term\n" > "$output_file"

declare -A map_uniprot
while IFS=$'\t' read -r geneid uniprot_col symbol; do
	# Split the uniprot column by comma
	IFS=',' read -ra uniprots <<< "$uniprot_col"
	for unis in "${uniprots[@]}"; do
		[[ -n "$unis" && -n "$symbol" ]] && map_uniprot["$unis"]="$symbol"
	done
done < "$gene_map"

total_terms=$(($(wc -l < "$enriched_fields_file") - 1))
term_index=0

{
	read # skip header
	while IFS=$'\t' read -r term name source _4 _5 _6 _7 querysize cov interS termS; do
		((term_index++))
		printf "Processing %s/%s: %s\n" "$term_index" "$total_terms" "$term"

		s_term=$(echo "$term" | sed 's/:/_/g')
		s_name=$(echo "$name" | sed 's/[^a-zA-Z0-9_-]/_/g' | sed 's/__+/_/g')

		output_dir="${save_dir}/${source}/terms_annotations"
		term_dir="${output_dir}/${s_term}_${s_name}"
		mkdir -p "$term_dir"

		genes_in_term="$term_dir/genes_in_term"
		uniprots_in_term="$term_dir/uniprots_in_term"
		genes_in_intersection="$term_dir/genes_in_intersection"
		unmapped_uniprots="$term_dir/obsolete_or_merged_uniprots"
		
		: > "$genes_in_term"
		: > "$uniprots_in_term"

		# get uniprots for PANTHER and Reactome
		if [[ "$source" == *PANTHER* ]]; then
			awk -F'\t' -v term="$term" '$3 ~ "(^|;)" term "(;|$)" {print $1}' "$panther_annot" | sort -u > "$uniprots_in_term"
		elif [[ "$source" == *REAC* ]]; then
			awk -F'\t' -v term="$term" '$1 == term { n = split($3, arr, ","); for (i = 1; i <= n; i++) print arr[i] }' "$reac_annot" | sort -u > "$uniprots_in_term"
		elif [[ "$source" == GO_* && "$source" != *PANTHER* ]]; then
			./gos_annots.sh "$species_taxon" "$term" "$term_dir" "$go_annot"
		fi

		# convert uniprots to symbols for non-GO sources
		if [[ -s "$uniprots_in_term" ]]; then
			while read -r uniprot; do
				if [[ -n "${map_uniprot["$uniprot"]}" ]]; then
					# Replace internal semicolons with pipes for safety
					echo "${map_uniprot["$uniprot"]}" >> "$genes_in_term"
				else
					echo "$uniprot" >> "$unmapped_uniprots"
				fi
			done < "$uniprots_in_term"
		fi

		# intersection matching
		if [[ -s "$uniprots_in_term" ]]; then
			# match against input_list (column 2 is UniProt)
			awk -F'\t' 'NR==FNR { u[$1]; next } ($2 in u) { print $0 }' "$uniprots_in_term" "$input_list" > "$genes_in_intersection"
		elif [[ -s "$genes_in_term" ]]; then
			# Match against input_list (assuming column 3 is Symbol)
			awk -F'\t' 'NR==FNR { g[$1]; next } ($3 in g) { print $0 }' "$genes_in_term" "$input_list" > "$genes_in_intersection"
		fi

		# final metrics calculations and output
		if [[ ! -f "$genes_in_term" || ! -s "$genes_in_term" ]]; then continue; fi

		term_size=$(wc -l < "$genes_in_term")
		intersection_size=0
		intersection_genes_str=""
		
		if [[ -s "$genes_in_intersection" ]]; then
			intersection_size=$(wc -l < "$genes_in_intersection")
			intersection_genes_str=$(awk -F'\t' '{ printf "%s ", $3 }' "$genes_in_intersection")
		fi
		
		coverage=$(awk -v m="$intersection_size" -v t="$term_size" 'BEGIN { if (t > 0) printf "%.2f", (m / t)*100; else print 0 }')
		all_genes_in_term=$(paste -sd' ' "$genes_in_term")

		# final output for this term
		printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
			"$term" "$name" "$source" "$coverage" "$intersection_size" "${intersection_genes_str% }" "$term_size" "$all_genes_in_term" >> "$output_file"

	done
} < "$enriched_fields_file"