#!/bin/bash

if [ $# -ne 5 ]; then
	printf "Usage: %s <ids_list_map> <species_name> <panther_annotations> <reac_annotations> <uniprot_map>\n" "$0"
	exit 1
fi

input_list="$1"
species="$2"
panther_annot="$3"
reac_annot="$4"
uniprot_map="$5"
results_file="long_results.csv"

for file in "$panther_annot" "$reac_annot" "$uniprot_map"; do
	if [ ! -f "$file" ]; then
		printf "Error: %s not found.\n" "$file"
		exit 1
	fi
done

go_cache_file="go_annotations_cache"

# FUNCTION TO FETCH GO ANNOTS
get_go_terms_annotations() {
	local GO_TERM="$1"
	local TAXON_LABEL="$2"
	local TERM_DIR="$3"

	local GO_TERM_ENC="${GO_TERM/:/%3A}"
	local TAXON_LABEL_ENC="${TAXON_LABEL// /%20}"
	local output_file
    output_file=$(mktemp)
	local genes_file="${TERM_DIR}/genes_in_term"

	# cache?
	if genes_line=$(grep -P "^${GO_TERM}\t" "$go_cache_file" 2>/dev/null); then
		genes_line=$(echo "$genes_line" | cut -f2-)
		echo "$genes_line" | tr ' ' '\n' | sort -u > "$genes_file"
		return
	fi

	curl -s "https://golr-aux.geneontology.io/solr/select?defType=edismax&qt=standard&indent=on&wt=csv&rows=100000&start=0&fl=bioentity_label&facet=false&fq=document_category:%22annotation%22&fq=isa_partof_closure:%22$GO_TERM_ENC%22&fq=taxon_subset_closure_label:%22$TAXON_LABEL_ENC%22&q=*%3A*" -o "$output_file"

	if [[ $(wc -l < "$output_file") -gt 1 ]]; then
		awk -F'\t' 'NR > 1 && $1 != "" && !seen[$1]++ { print $1 }' "$output_file" > "$genes_file"
	else
		printf "Gene Ontology term %s could have been obsoleted.\n" "$GO_TERM"
		: > "$genes_file"
	fi
	rm -f "$output_file"

	genes_joined=$(paste -sd' ' "$genes_file")
	echo -e "${GO_TERM}\t${genes_joined}" >> "$go_cache_file"
}

output_file="terms_annotations_results.csv"
printf "TermID,Name,Source,Plus_Minus,Fold_Enrichment,Ratio(%%),ListCount,Genes_in_list,TermCount,Genes_in_term\n" > "$output_file"

declare -A map_uniprot
while IFS=$'\t' read -r uniprot symbol name organism; do
	[[ -n "$uniprot" && -n "$symbol" ]] && map_uniprot["$uniprot"]="$symbol"
done < "$uniprot_map"

total_terms=$(($(wc -l < "$results_file") - 1))
term_index=0

{
	read
	while IFS=',' read -r term name _3 _4 fold plus_minus source _8 _9; do
		((term_index++))
		printf "Processing enriched term annotations %s/%s: %s (%s)\n" "$term_index" "$total_terms" "$term" "$name"

		output_dir="results/${source}/terms_annotations"
		mkdir -p "$output_dir"

		sanitized_name=$(printf "%s" "$name" | sed 's/,/ /g')
		term_dir="${output_dir}/${term}_${sanitized_name}"
		mkdir -p "$term_dir"

		genes_in_term="$term_dir/genes_in_term"
		uniprots_in_term="$term_dir/uniprots_in_term"
		genes_in_list="$term_dir/genes_in_list"

		# get uniprots for PANTHER and Reactome datasets
		if [[ "$source" == *PANTHER* ]]; then
			awk -F'\t' -v term="$term" '$2 ~ "(^|;)" term "(;|$)" {print $1}' "$panther_annot" 2>/dev/null | sort -u > "$uniprots_in_term"
			if [[ ! -s "$uniprots_in_term" ]]; then
				printf "\nNo annotations found for term '%s' in PANTHER annotations file.\n" "$name"
			else
				# convert uniprots to symbols
				while read -r uniprot; do
					[[ -z "$uniprot" ]] && continue
						if [[ -n "${map_uniprot["$uniprot"]}" ]]; then
							echo "${map_uniprot["$uniprot"]//[; ]/|}" >> "$genes_in_term"	# join symbols by | associated to same uniprot
						else
							echo "$uniprot" >> "$unmapped_uniprots"
						fi
				done < "$uniprots_in_term"
			fi
		elif [[ "$source" == *REAC* ]]; then
			awk -F'\t' -v term="REAC:$term" '
			$1 == term {
				for (i = 3; i <= NF; i++) {
					print $i
				}
			}' "$reac_annot" | sort -u > "$genes_in_term"
			if [[ ! -s "$genes_in_term" ]]; then
				printf "\nNo annotations found for term '%s' in REACTOME annotations file.\n" "$name"
			fi
		# get symbols for gos
		elif [[ "$source" == GO_* && "$source" != *PANTHER* ]]; then
			get_go_terms_annotations "$term" "$species" "$term_dir"
		else
			continue
		fi

		# match uniprots (2col) to input list for PANTHER > accuracy
		if [[ -s "$uniprots_in_term" ]]; then
			awk -F'\t' '
				NR==FNR { term[$1]; next }
				($2 in term) { print $0 }
			' "$uniprots_in_term" "$input_list" > "$genes_in_list"

		# match symbols (3col) to input list
		elif [[ -s "$genes_in_term" ]]; then
			awk -F'\t' '
				NR==FNR { term[$1]; next }
				($3 in term) { print $0 }
			' "$genes_in_term" "$input_list" > "$genes_in_list"
		fi

		unmapped_uniprots="$term_dir/obsolete_or_merged_uniprots"

		if [[ ! -f "$genes_in_term" ]]; then
			printf "Skipping term '%s' — not found.\n" "$term"
			continue
		fi

		term_count=$(awk 'END{print NR}' "$genes_in_term")
		matched_count=0
		matched_genes=""
		if [[ -s "$genes_in_list" ]]; then	# deal with obsolete gos
			matched_count=$(awk 'END {print NR}' "$genes_in_list")
			matched_genes=$(awk -F'\t' '{ printf "%s ", $3 }' "$genes_in_list")
		fi
		ratio=$(awk -v m="$matched_count" -v t="$term_count" 'BEGIN { if (t > 0) printf "%.2f", (m / t)*100; else print 0 }')

		term_annotations=$(paste -sd' ' "$genes_in_term")
		printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" \
			"$term" "$sanitized_name" "$source" "$plus_minus" "$fold" "$ratio" "$matched_count" "${matched_genes% }" "$term_count" "$term_annotations" >> "$output_file"
	done
} < "$results_file"