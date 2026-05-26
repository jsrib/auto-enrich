#!/bin/bash

if [ $# -ne 8 ]; then
	printf "Usage: %s <input_map_file> <results_file> <species_taxon> <save_dir> <panther_annot> <reac_annot> <go_annot> <gene_map>\n" "$0"
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
pos_output_file="enriched_terms_annotations_pos.tsv"
neg_output_file="enriched_terms_annotations_neg.tsv"

# validate files
for file in "$panther_annot" "$reac_annot" "$go_annot" "$gene_map" "$input_list"; do
	if [ ! -f "$file" ]; then
		printf "❌ Error: Required file not found: '%s'.\n" "$file"
		exit 1
	else
		sed -i 's/\r$//' "$file"
	fi
done

printf "TermID\tName\tSource\tCoverage\tIntersectionSize\tGenes_in_intersection\tTermSize\tGenes_in_term\n" > "$pos_output_file"
printf "TermID\tName\tSource\tCoverage\tIntersectionSize\tGenes_in_intersection\tTermSize\tGenes_in_term\n" > "$neg_output_file"

# pre-extract input symbols for intersection
cut -f3 "$input_list" | sort -u > .input_symbols.tmp

#total_terms=$(($(wc -l < "$enriched_fields_file") - 1))
#term_index=0

while IFS=$'\t' read -r term name source _4 _5 _6 direction querysize cov interS termS; do
	[[ -z "$term" || "$term" == "TermID" || "$term" == "UNCLASSIFIED" || "$source" == "UNCLASSIFIED" ]] && continue
	#((term_index++))
	#printf "Processing %s/%s: %s %s\n" "$term_index" "$total_terms" "$source" "$term"

	if [[ $direction == "+" ]]; then
		output_file="$pos_output_file"
	elif [[ $direction == "-" ]]; then
		output_file="$neg_output_file"
	else
		continue
	fi

	# Define paths
	source_dir="${save_dir}/${source}"
	[[ ! -d "$source_dir" ]] && mkdir -p "$source_dir"
	s_term="${term//:/_}"
	term_dir="${source_dir}/terms_annotations/${s_term}_${name}"
	mkdir -p "$term_dir"

	genes_in_term="$term_dir/genes_in_term"
	genes_in_intersection="$term_dir/genes_in_intersection"

	# standardize extraction (always use unique gene symbols)
	case "$source" in
		*PANTHER*)
			awk -F'\t' -v term="$term" '$3 ~ "(^|;)" term "(;|$)" {print $2}' "$panther_annot" 2>/dev/null | sort -u > "$genes_in_term"
			;;
		*REAC*)
			# map UniProt (col 3) to symbol via gene_map (col 2=UniProt, col 3=Symbol)
			awk -F'\t' -v t="$term" '$1 == t {print $3}' "$reac_annot" | tr ',' '\n' | \
			awk -F'\t' 'NR==FNR {map[$2]=$3; next} $1 in map {print map[$1]}' "$gene_map" - | sort -u > "$genes_in_term"
			;;
		GO_BP|GO_MF|GO_CC)
			awk -F'\t' -v t="$term" '$1 == t {print $2}' "$go_annot" | tr ',' '\n' | sort -u > "$genes_in_term"
			;;
	esac

	[[ -s "$genes_in_term" ]] || echo "" > "$genes_in_term"

	# intersection
	grep -Fxf .input_symbols.tmp "$genes_in_term" > "$genes_in_intersection" || :

	# metrics
	term_size=$(wc -l < "$genes_in_term")
	intersection_size=$(wc -l < "$genes_in_intersection")
	coverage=$(awk -v m="$intersection_size" -v t="$term_size" 'BEGIN { printf "%.4f", (t>0 ? (m/t) : 0) }')

	genes_in_intersection_str="$(paste -sd ' ' "$genes_in_intersection" 2>/dev/null || echo '')"
	genes_in_term_str="$(paste -sd ' ' "$genes_in_term" 2>/dev/null || echo '')"
	
	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
			"$term" \
			"$name" \
			"$source" \
			"$coverage" \
			"$intersection_size" \
			"$genes_in_intersection_str" \
			"$term_size" \
			"$genes_in_term_str" >> "$output_file"

done < "$enriched_fields_file"

# Cleanup
rm .input_symbols.tmp