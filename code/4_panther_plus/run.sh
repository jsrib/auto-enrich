#!/bin/bash
# PANTHER_plus Module 4
cd /opt/4_panther_plus
#set -eo pipefail

if [ $# -lt 2 ]; then
	printf "Usage: %s <ids_map_file> <species> [panther_dbs]\n" "$0"
	exit 1
fi

input_file="/data/$1"
species="$2"
panther_dbs="${3:-}"

if [ ! -f "${input_file}" ]; then
	printf "Error: Input file '%s' not found.\n" "$input_file"
	exit 1
fi

results_dir="results"
# get species taxon, name, long and short from PANTHER supported_genomes
source ./normalize_name.sh "$species"

if [[ -z "$taxon_id" || -z "$name" || -z "$long_name" || -z "$short_name" ]]; then
	printf "Input species '%s' not found.\n" "$species"
	exit 1
fi

printf "Taxon ID, common and species name of '%s': %s, %s, %s and %s.\n" \
	"$species" "$taxon_id" "$name" "$long_name" "$short_name"

panther_annot="${short_name}_PTHR19.0_annotations"
reac_annot="${short_name}_REAC_annotations"
uniprots_map="${short_name}_gene_uniprot"
[[ ! -f "/data/$panther_annot" ]] && ./panther_annotations.sh "$name" "$short_name" && cp "$panther_annot" /data 2>/dev/null
[[ ! -f "/data/$reac_annot" ]] && ./reactome_annotations.sh "$long_name" "$short_name" && cp "$reac_annot" /data 2>/dev/null
[[ ! -f "/data/$uniprots_map" ]] && ./uniprot_map_symbol.sh "$short_name" "$taxon_id" && cp "$uniprots_map" /data 2>/dev/null

rm -rf "$results_dir"
mkdir -p "$results_dir"

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
./get_terms_annotations.sh "${input_file}" "${long_name}" "/data/${panther_annot}" "/data/${reac_annot}" "/data/${uniprots_map}"

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