#!/bin/bash
# GSEA plus Module 6
cd /opt/6_gsea_plus
set -euo pipefail

if [ $# -ne 2 ]; then
	printf "Usage: %s <parameters_file> <save_dir>\n" "$0"
	exit 1
fi

param_file="$1"
save_dir="$2"
cp $param_file .

head -50 $param_file

if [ ! -f "${param_file}" ]; then
	printf "❌ [MODULE 6] Configuration Error: Parameter file '${param_file}' not found.\n"
	exit 1
else
	# nornalize windows /r to prevent erros with GSEA
	sed -i 's/\r//' "${param_file}"
	# auto-fix: add newline to end of file to precent GSEA error
	if [[ $(tail -c1 "${param_file}") != "" ]]; then
		printf "\n" >> "${param_file}"
	fi
fi

rnk_file=""
res_file=""
cls_file=""
gmx_file=""
chip_file=""
out_dir=""

# read parameteres
while IFS=$'\t' read -r key value; do
	case "$key" in
		rnk)  rnk_file="$value" ;;
		res)  res_file="$value" ;;
		cls)  cls_file="$value" ;;
		gmx)  gmx_file="$value" ;;
		chip) chip_file="$value" ;;
		out)  out_dir="$value" ;;
		collapse) collapse_mode="$value" ;;
	esac
done < "${param_file}"

# gmx provided?
if [[ -z "$gmx_file" ]]; then
	printf "❌ [MODULE 6] Configuration Error: 'gmx' parameter is required.\n"
	exit 1
else
	# prefix for output dir name
	gmx_base=$(basename "$gmx_file")
	gmx_prefix=$(echo "$gmx_base" | sed -E 's/\.v[0-9]+\.[0-9]+.*//')
fi

# create save dir if doesnt exist
if [[ ! -d "/$save_dir" ]]; then
	mkdir -p "/$save_dir"
fi

# handle chip file, only necessary if collapse ON
if [[ "$collapse_mode" == "Collapse" || "$collapse_mode" == "Remap_Only" ]]; then
	if [[ ! -f "$chip_file" ]]; then
		printf "❌ [MODULE 6] File Missing: chip file '%s' not found.\n" "${chip_file}"
		exit 1
	fi
fi

# unpack and run gsea cli
zip_file="GSEA_LinuxIntel_4.4.0-WithJava.zip"
	if [[ ! -f "GSEA_Linux_4.4.0/gsea-cli.sh" ]]; then
		echo "Unzipping $zip_file..."
		unzip -q "$zip_file"
	fi

# GSEApreranked
if [[ -n "$rnk_file" ]]; then
	if [[ -n "$res_file" || -n "$cls_file" ]]; then
		printf "❌ [MODULE 6] Configuration Error: For GSEAPreranked, 'res' and 'cls' must NOT be set.\n"
		exit 1
	fi

	# check required files in ./
	for file in "$rnk_file" "$gmx_file"; do
		if [[ ! -f "$file" ]]; then
			printf "File not found: '%s'.\n" "$file"
			exit 1
		fi
	done

	printf "➡ Running GSEAPreranked...\n"
	./GSEA_Linux_4.4.0/gsea-cli.sh GSEAPreranked -param_file "${param_file}" -collapse "${collapse_mode}" -chip "${chip_file}"
	
	# rename new directory to include rnk filename
	gsea_result_dir=$(find "${out_dir}" -maxdepth 1 -type d -name "my_analysis.GseaPreranked.*" 2>/dev/null)
	if [[ -n "$gsea_result_dir" ]]; then
		rnk_base=$(basename "${rnk_file%.*}") # remove file extension for name
		results_dir="${rnk_base}.${gmx_prefix}.GseaPreranked"
		echo "Renamed GSEA Preranked result directory to: $results_dir"
	else
		mv "$out_dir" "$save_dir"
		exit 1
	fi
# GSEA classic
elif [[ -n "$res_file" && -n "$cls_file" ]]; then
	if [[ -n "$rnk_file" ]]; then
		printf "❌ [MODULE 6] Configuration Error: For GSEA Classic, 'rnk' must NOT be set.\n"
		exit 1
	fi

	# check required files in ./
	for file in "$res_file" "$cls_file" "$gmx_file"; do
		if [[ ! -f "$file" ]]; then
			printf "File not found: '%s'.\n" "$file"
			exit 1
		fi
	done

	printf "➡ Running GSEA Classic...\n"
	./GSEA_Linux_4.4.0/gsea-cli.sh GSEA -param_file "${param_file}" -collapse "${collapse_mode}" -chip "${chip_file}"

	# rename new directory to include phenotypes
	gsea_result_dir=$(find "${out_dir}" -maxdepth 1 -type d -name "my_analysis.Gsea.*" 2>/dev/null)
	if [[ -n "$gsea_result_dir" ]]; then
		label_line=$(sed -n '2p' "$cls_file")
		label_names=$(echo "$label_line" | cut -c3-)
		label_name=$(echo "$label_names" | sed 's/ \+/_vs_/g')
		results_dir="${label_name}.${gmx_prefix}.GseaClassic"
		printf "Renamed GSEA Classic result directory to: %s\n" "$results_dir"
	else
		mv "$out_dir" "$save_dir"
		exit 1
	fi
# wrong config
else
	printf "\nError: Invalid parameter combination. Provide either:\n"
	printf "   - 'rnk' and 'gmx' only for GSEAPreranked\n"
	printf "   OR\n"
	printf "   - 'res', 'cls', and 'gmx' only for GSEA Classic\n"
	exit 1
fi

mkdir -p "$results_dir"
# change gsea results directory
mv "$gsea_result_dir" "raw_GSEA_output"
mv "raw_GSEA_output" "$results_dir"
# get reports file for results
report_files=$(find "$results_dir/raw_GSEA_output" -type f -name "gsea_report_*.tsv")
# for file in $report_files; do
# 	cp "$file" "$results_dir/"
# done

printf "Processing report files...\n"
fields_results="enrichment_fields.tsv"
./process_reports.sh "${results_dir}" "${fields_results}"

printf "Getting enriched terms annotations...\n"
./get_terms_annotations.sh "${results_dir}" "$fields_results" "$gmx_file"
annots_results="enriched_terms_annotations.tsv"

mv "$results_dir" "$save_dir"

# split results by source
for file in "$fields_results" "$annots_results"; do
	[[ ! -f "$file" ]] && continue
	# check if file empty
	line_count=$(wc -l < "$file")
	if (( line_count <= 1 )); then
		printf "No statistically significant results in %s\n" "$file"
		exit 1
	fi
	# copy files to results directory (already in save_dir)
	cp "${file}" "${save_dir}/${results_dir}/"
	src_col=2 #source column in files
	header=$(head -n 1 "$file")
	# get unique sources from the file
	mapfile -t sources < <(tail -n +2 "$file" | awk -F'\t' -v col="$src_col" '{print $col}' | sort -u)
	for src in "${sources[@]}"; do
		[[ -z "$src" ]] && continue
		# create source-specific directory
		src_dir="${save_dir}/${results_dir}/$src"
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

