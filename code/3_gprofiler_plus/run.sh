#!/bin/bash
<<<<<<< HEAD
# gProfiler module 3
cd /opt/3_gprofiler_plus
set -euo pipefail

if [ $# -lt 4 ]; then
	printf "Usage: %s <input_map_file> <gprof_curl_id> <gene_sets_file> <save_dir> [gprofiler_dbs]\n" "$0"
	exit 1
fi

input="$1"
gprof_curl_id="$2"	# gprofiler curl id (from organism index file [id])
gmt_file="$3"
save_dir="$4"
gprofiler_dbs="${5:-}"

if [[ -d "$save_dir" ]]; then
	if [[ -n "$(ls -A "$save_dir" 2>/dev/null)" ]]; then
		printf "❌ [MODULE 3] Error: Directory '%s' already exists and is NOT empty. Please clear it first.\n" "$save_dir" >&2
		exit 1
	fi
else
	mkdir -p "$save_dir"
fi

if [ ! -f "${input}" ]; then
	printf "❌ [MODULE 3] Input File Missing: Input gene map file '%s' not found.\n" "${input}" >&2
	exit 1
fi

# download (if not present) the gprofiler gene sets file *species specific 
if [ ! -s "${gmt_file}" ]; then
	./genes_sets_species.sh "${gprof_curl_id}" "${gmt_file}"
	if [[ ! -s "$gmt_file" ]]; then
		printf "❌ [MODULE 3] Error: gProfiler Gene Sets file download failed or file is empty."
		exit 1
	fi
else
	printf "g:Profiler annotations file found for %s.\n" "$gmt_file"
fi

./request_curl.sh "${input}" "${gprof_curl_id}" "${gprofiler_dbs}"
raw_out="raw_output"

# process raw into enriched fields output file
fields_results="enrichment_fields.tsv"
./process_raw.sh "${raw_out}" "${fields_results}"
cp "$fields_results" "${save_dir}/"

./get_term_genes.sh "${input}" "${gmt_file}" "${fields_results}" "${save_dir}"
annots_results="enriched_terms_annotations.tsv"
cp "$annots_results" "${save_dir}/"

# split results by source
for file in "$fields_results" "$annots_results"; do
	[[ ! -f "$file" ]] && continue

	# check if file empty
	line_count=$(wc -l < "$file")
	if (( line_count <= 1 )); then
		printf "No statistically significant results in %s\n" "$file"
		exit 1
	fi

	# determine the Source column based on the filename (3 in fields_results, 4 in annots_results)
	if [[ "$file" == "$fields_results" ]]; then
		src_col=4
	else
		src_col=3
	fi

	header=$(head -n 1 "$file")
	
	# get unique sources from the file
	mapfile -t sources < <(tail -n +2 "$file" | awk -F'\t' -v col="$src_col" '{print $col}' | sort -u)

	for src in "${sources[@]}"; do
		[[ -z "$src" ]] && continue
		
		# create source-specific directory
		src_dir="$save_dir/$src"
		if [[ ! -d "$src_dir" ]]; then
			mkdir -p "$src_dir"
		fi

		# filter the file for this source and save as TSV
		{
			echo "$header"
			awk -F'\t' -v col="$src_col" -v val="$src" '$col == val' "$file"
		} > "$src_dir/${src}_$file"
	done
done
=======
# gProfiler plus Module 3
cd /opt/3_gprofiler_plus
#set -euo pipefail

if [ $# -lt 2 ]; then
	printf "Usage: %s <ids_map_file> <species> [gprofiler_dbs]\n" "$0"
	exit 1
fi

input_file="/data/$1"
species="$2"
gprofiler_dbs="${3:-}"

results_dir="results"
rm -rf "$results_dir"
mkdir -p "$results_dir"

if [ ! -f "${input_file}" ]; then
	printf "Error: Input IDs map file '%s' not found.\n" "$input_file"
	exit 1
fi

gmt_file="${species}_gProfiler_annotations.gmt"
if [ ! -f "/data/${gmt_file}" ]; then
	./genes_sets_species.sh "${species}"
	cp "$gmt_file" /data 2>/dev/null
else
	printf "g:Profiler annotations file found for %s.\n" "$species"
fi

./request_curl.sh "${input_file}" "${species}" "${gprofiler_dbs}"
raw_out="raw_output"
./process_output.sh "${raw_out}"	
./get_term_genes.sh "${input_file}" "/data/${gmt_file}"

for file in *_results.csv; do
	[[ ! -f "$file" ]] && continue

	line_count=$(wc -l < "$file")
	if (( line_count <= 1 )); then
		printf "No statistically significant results in %s\n" "$file"
		exit 2
	fi
	cp "$file" "$results_dir/"
	case "$file" in
		short_results.csv) src_col=4 ;;
		long_results.csv)  src_col=10 ;;
		terms_annotations_results.csv) src_col=3 ;;
		*) continue ;;
	esac

	header=$(head -n 1 "$file")
	mapfile -t sources < <(tail -n +2 "$file" | awk -F',' -v col="$src_col" '{print $col}' | sort -u)
	for src in "${sources[@]}"; do
		[[ -z "$src" ]] && continue
		mkdir -p "$results_dir/$src"
		{
			echo "$header"
			awk -F',' -v col="$src_col" -v val="$src" '$col == val' "$file"
		} > "$results_dir/$src/${src}_$file"
	done
done

mv "${results_dir}" /data
rm *_results.csv
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
