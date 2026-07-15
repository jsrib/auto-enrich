#!/bin/bash
# PANTHER_plus Module 4
cd /opt/4_panther_plus
<<<<<<< HEAD

if [ $# -lt 8 ]; then
	printf "Usage: %s <input_map_file> <species> <save_dir> <panther_annotations> <reactome_annotations> <gos_annotations> <gene_map> [panther_dbs]\n" "$0"
	exit 1
fi

input_file="$1"
species_taxon="$2"
save_dir="$3"
panther_annot="$4"
reactome_annot="$5"
gos_annot="$6"
gene_map="$7"
panther_dbs="${8:-}"

if [ ! -f "${input_file}" ]; then
	printf "❌ [MODULE 4] Error: Input file '%s' not found.\n" "$input_file"
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

# with taxon get species scientific and common names from PANTHER supported_genomes file (from API) and save to variables
source ./normalize_name.sh "$species_taxon"

if [[ -z "$scientific_name" || -z "$common_name" ]]; then
	printf "❌ [MODULE 4] Error: Input species '%s' not found.\n" "$species_taxon"
	exit 1
fi

if [[ ! -s "$panther_annot" ]]; then 
	./panther_annotations.sh "$common_name" "panther_annotations" 2>/dev/null
	if [[ ! -s "panther_annotations" ]]; then
		printf "❌ [MODULE 4] Error: PANTHER Annotations file download failed or file is empty.\n"
		exit 1
	else
		mv "panther_annotations" "${panther_annot}"
	fi
else
	printf "PANTHER annotations file found: '%s'.\n" "$panther_annot"
fi

if [[ ! -s "$reactome_annot" ]]; then
	./reactome_annotations.sh "$scientific_name" "$reactome_annot"
	if [[ ! -s "$reactome_annot" ]]; then
		printf "❌ [MODULE 4] Error: REACTOME Annotations file download failed or file is empty.\n"
		exit 1
	fi
else
	printf "REACTOME annotations file found: '%s'.\n" "$reactome_annot"
fi

if [[ ! -s "$gos_annot" ]]; then
	printf "Generating Gene Ontology GAF Annotations....\n" "$gos_annot"	
	python3 build_gos_gaf_symbols.py "$scientific_name" "$gos_annot"
	if [[ ! -s "$gos_annot" ]]; then
		printf "❌ [MODULE 4] Error: Gene Ontology GAF Annotations file download failed or file is empty.\n"
		exit 1
	fi
else
	printf "Gene Ontology GAF Annotations file found: '%s'.\n" "$gos_annot"
fi

if [ ! -s "${gene_map}" ]; then
	# download gene mapping file for the species (mandatory to gather terms annotations)
	/opt/2_gene_mapping/id_uniprot_symbol_mapping.sh "$species_taxon" "$gene_map"
	if [[ ! -s "$gene_map" ]]; then
		printf "❌ [MODULE 4] Error: Species gene map file '%s' not found.\n" "$gene_map"
		exit 1
	fi
fi

# run panther curl with input file and taxon id
=======
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

>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
./panther_curl.sh "${input_file}" "${taxon_id}" "${panther_dbs}"
raw_out=($(ls output_* 2>/dev/null || true))

if [ ${#raw_out[@]} -eq 0 ]; then
<<<<<<< HEAD
	printf "❌ [MODULE 4] Error: No output enrichment results files to be processed found.\n"
=======
	printf "No output files to be processed found.\n"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
	exit 1
fi

for dataset in "${raw_out[@]}"; do
<<<<<<< HEAD
	./process_raws.sh "$dataset"
done

# join results into a single file with source as column
fields_results="enrichment_fields.tsv"
printf "TermID\tName\tSource\tpValue\tpValue_FDR\tFold_Enrichment\tDirection\tQuerySize\tCoverage\tIntersectionSize\tTermSize\n" > "$fields_results"

result_files=($(ls results_*))
for file in "${result_files[@]}"; do
	if [ -f "$file" ] && [ "$(wc -l < "$file")" -gt 1 ]; then
		printf "Statistically significant results found for %s.\n" "$file"
		tail -n +2 "$file" | cat >> "$fields_results"
	else
		printf "⚠️ No statistically significant results found for '%s' gene set.\n" "$file"
	fi
done

cp "./$fields_results" "$save_dir/"

# get enriched terms annotations
printf "Getting enriched terms annotations (may take a while)...\n"
./get_terms_annotations.sh "${input_file}" "${fields_results}" "${species_taxon}" "${save_dir}" "${panther_annot}" "${reactome_annot}" "${gos_annot}" "${gene_map}"
pos_annots_results="enriched_terms_annotations_pos.tsv"
neg_annots_results="enriched_terms_annotations_neg.tsv"
cp "./$pos_annots_results" "$save_dir/"
cp "./$neg_annots_results" "$save_dir/"

# split results by source
for file in "$fields_results" "$pos_annots_results" "$neg_annots_results"; do
	[[ ! -f "$file" ]] && continue
	# check if file empty
	line_count=$(wc -l < "$file")
	if (( line_count <= 1 )); then
		printf "No statistically significant results in %s\n" "$file"
		continue
	fi
	# Source column
	src_col=3
	header=$(head -n 1 "$file")
	# get unique sources from the file
	mapfile -t sources < <(tail -n +2 "$file" | awk -F'\t' -v col="$src_col" '{print $col}' | sort -u)
	for src in "${sources[@]}"; do
		[[ -z "$src" ]] && continue
		# create source-specific directory
		src_dir="$save_dir/$src"
		[[ ! -d "$src_dir" ]] && mkdir -p "$src_dir"
		# filter the file for this source and save as TSV
		{
			echo "$header"
			awk -F'\t' -v col="$src_col" -v val="$src" '$col == val' "$file"
		} > "$src_dir/${src}_$file"
	done
done
=======
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
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
