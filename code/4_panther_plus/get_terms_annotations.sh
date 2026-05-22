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

# temporary uniprot symbol map
awk -F'\t' '{split($2, u, ","); for(i in u) print u[i] "\t" $3}' "$gene_map" > .gene_map_lookup.tmp

total_terms=$(($(wc -l < "$enriched_fields_file") - 1))
term_index=0

while IFS=$'\t' read -r term name source _4 _5 _6 _7 querysize cov interS termS; do
	[[ -z "$term" || "$term" == "TermID" || "$term" == "*UNCLASSIFIED*" ]] && continue
	((term_index++))
	printf "Processing %s/%s: %s %s\n" "$term_index" "$total_terms" "$source" "$term"

	unset term_data

	# safe name dir creation
	s_term=$(echo "$term" | sed 's/:/_/g')
	s_name=$(echo "$name" | sed 's/[^a-zA-Z0-9_-]/_/g' | sed 's/__+/_/g')
	term_dir="${save_dir}/${source}/terms_annotations/${s_term}_${s_name}"
	mkdir -p "$term_dir"

	genes_in_term="$term_dir/genes_in_term"
	uniprots_in_term="$term_dir/uniprots_in_term"
	genes_in_intersection="$term_dir/genes_in_intersection"
	
	: > "$genes_in_term"
	: > "$uniprots_in_term"

	unset term_data

	# different annotation process per source
	if [[ "$source" == *PANTHER* ]]; then
		term_data=$(grep -w "^$term" "$panther_annot")
	elif [[ "$source" == *REAC* ]]; then
		term_data=$(awk -F'\t' -v term="$term" '$1 == term { n = split($3, arr, ","); for (i = 1; i <= n; i++) print term "\t" arr[i] }' "$reac_annot" | \
					awk -F'\t' 'NR==FNR{map[$1]=$2; next} $2 in map {print $1 "\t" $2 "\t" map[$2]}' .gene_map_lookup.tmp -)
	elif [[ "$source" == GO_* ]]; then
		./gos_annots.sh "$species_taxon" "$term" "$term_dir" "$go_annot"
		# We assume gos_annots.sh populated the files, so we just read them back
		# [[ -f "$term_dir/results.tsv" ]] && term_data=$(awk -v t="$term" '{print t "\t" $1 "\t" $2}' "$term_dir/results.tsv")
	fi

	[[ -z "$term_data" ]] && continue

	echo "$term_data" | cut -f2 | sort -u > "$term_dir/uniprots_in_term"
	echo "$term_data" | cut -f3 | sort -u > "$term_dir/genes_in_term"

	# intersection of genes list with term
	intersection_data=$(echo "$term_data" | awk -F'\t' -v list="$input_list" '
		BEGIN { while((getline < list) > 0) seen[$2] }
		$2 in seen && $3 != "" { print $3 }  # Ensure only non-empty symbols are printed
	')
	
	# Write intersection file
	echo "$intersection_data" > "$term_dir/genes_in_intersection"

	# 5. Calculate final metrics from variables
	term_size=$(wc -l < "$term_dir/genes_in_term")
	intersection_size=$(echo "$intersection_data" | wc -l)
	[[ -z "$intersection_data" ]] && intersection_size=0
	intersection_genes_str=$(echo "$intersection_data" | tr '\n' ' ' | sed 's/ $//')
	all_genes_in_term=$(echo "$term_data" | cut -f3 | sort -u | tr '\n' ' ' | sed 's/ $//')
	
	coverage=$(awk -v m="$intersection_size" -v t="$term_size" 'BEGIN { printf "%.4f", (t>0 ? (m/t) : 0) }')

	# Output row
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$term" "$name" "$source" "$coverage" "$intersection_size" \
		"$intersection_genes_str" "$term_size" "$all_genes_in_term" >> "$output_file"
done < "$enriched_fields_file"

rm .gene_map_lookup.tmp