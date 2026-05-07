#!/bin/bash
# PANTHER_plus Module 4
cd /opt/4_panther_plus
#set -eo pipefail

if [ $# -lt 6 ]; then
	printf "Usage: %s <ids_map_file> <species> <panther_gene_sets> <reactome_gene_sets> <save_dir> [panther_dbs]\n" "$0"
	exit 1
fi

input_file="$1"
species_taxon="$2"
panther_gene_sets="$3"
reactome_gene_sets="$4"
save_dir="$5"
panther_dbs="${6:-}"

if [ ! -f "${input_file}" ]; then
	printf "[MODULE 4] Error: Input file '%s' not found.\n" "$input_file"
	exit 1
fi

if [[ -d "$save_dir" ]]; then
	if [[ -n "$(ls -A "$save_dir" 2>/dev/null)" ]]; then
		printf "❌ [MODULE 4] Error: Directory '%s' already exists and is NOT empty. Please clear it first.\n" "$save_dir" >&2
		exit 1
	fi
else
	mkdir -p "$save_dir"
fi

# with taxon get species scientific and common names from PANTHER supported_genomes
source ./normalize_name.sh "$species_taxon"

if [[ -z "$taxon_id" || -z "$scientific_name" || -z "$common_name" ]]; then
	printf "[MODULE 4] Error: Input species '%s' not found.\n" "$species_taxon"
	exit 1
fi

if [[ ! -f "/data/$panther_gene_sets" ]]; then 
	./panther_annotations.sh "$common_name" "$panther_gene_sets" 2>/dev/null
	if [[ ! -s "$panther_gene_sets" ]]; then
		printf "❌ [MODULE 4] Error: PANTHER Gene Sets file download failed or file is empty."
		exit 1
	fi
else
	printf "PANTHER annotations file found for %s.\n" "$panther_gene_sets"
fi

if [[ ! -f "/data/$reactome_gene_sets" ]]; then
	./reactome_annotations.sh "$scientific_name" "$reactome_gene_sets" 2>/dev/null
	if [[ ! -s "$reactome_gene_sets" ]]; then
		printf "❌ [MODULE 4] Error: REACTOME Gene Sets file download failed or file is empty."
		exit 1
	fi
else
	printf "REACTOME annotations file found for %s.\n" "$reactome_gene_sets"
fi

exit 0


./panther_curl.sh "${input_file}" "${taxon_id}" "${panther_dbs}"
raw_out=($(ls output_* 2>/dev/null || true))

if [ ${#raw_out[@]} -eq 0 ]; then
	printf "No output files to be processed found.\n"
	exit 1
fi

for dataset in "${raw_out[@]}"; do
	./process_output.sh "$dataset"
done

shopt -s nullglob	# avoid loop break if no files
for file in results_*; do
	if [ -f "$file" ] && [ "$(wc -l < "$file")" -gt 1 ]; then
		printf "✅ Statistically significant results found for %s.\n" "$file"
	else
		printf "⚠️ No statistically significant result found for %s gene set.\n" "$file"
	fi
done

./join_results.sh
./get_terms_annotations.sh "${input_file}" "${scientific_name}" "/data/${panther_annot}" "/data/${reac_annot}" "/data/${uniprots_map}"

for file in *_results.csv; do
	[[ ! -f "$file" ]] && continue
	if [ "$(wc -l < "$file")" -le 1 ]; then
		exit 2
	fi

	cp "$file" "$results_dir/"

	case "$file" in
		short_results.csv)	src_col=5 ;;
		long_results.csv)	src_col=7 ;;
		terms_annotations_results.csv)	src_col=3 ;;
		*) continue ;;
	esac

	header=$(head -n 1 "$file")
	mapfile -t sources < <(tail -n +2 "$file" | awk -F',' -v col="$src_col" '{print $col}' | sort -u)

	for source in "${sources[@]}"; do
		[[ -z "$source" ]] && continue
		src_dir="$results_dir/$source"
		mkdir -p "$src_dir"
		{
			echo "$header"
			awk -F',' -v col="$src_col" -v val="$source" '$col == val' "$file"
		} > "$src_dir/${source}_$file"
	done
done

rm -f *_results.csv
mv "$results_dir" /data