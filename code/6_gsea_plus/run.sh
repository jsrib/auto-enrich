#!/bin/bash
# GSEA plus Module 6
cd /opt/6_gsea_plus
set -euo pipefail

<<<<<<< HEAD
if [ $# -ne 2 ]; then
	printf "Usage: %s <parameters_file> <save_dir>\n" "$0"
=======
if [ $# -ne 1 ]; then
	printf "Usage: %s <gsea_parameters>\n" "$0"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
	exit 1
fi

param_file="$1"
<<<<<<< HEAD
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

=======

if [ ! -f "${param_file}" ]; then
	printf "\nError: Input file '${param_file}' not found.\n"
	exit 1
else
	sed -i 's/\r//' "${param_file}"	# nornalize windows /r to prevent erros with GSEA
fi

# auto-fix: add newline to end of file to precent GSEA error
if [[ $(tail -c1 "${param_file}") != "" ]]; then
	printf "\n" >> "${param_file}"
fi

param_file="$1"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
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
<<<<<<< HEAD
	printf "❌ [MODULE 6] Configuration Error: 'gmx' parameter is required.\n"
=======
	printf "\nError: 'gmx' parameter is required.\n"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
	exit 1
else
	# prefix for output dir name
	gmx_base=$(basename "$gmx_file")
	gmx_prefix=$(echo "$gmx_base" | sed -E 's/\.v[0-9]+\.[0-9]+.*//')
fi

<<<<<<< HEAD
# create save dir if doesnt exist
if [[ ! -d "$save_dir" ]]; then
	mkdir -p "$save_dir"
=======
if [[ ! -d "/data/$out_dir" ]]; then
	mkdir -p "/data/$out_dir"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
fi

# handle chip file, only necessary if collapse ON
if [[ "$collapse_mode" == "Collapse" || "$collapse_mode" == "Remap_Only" ]]; then
<<<<<<< HEAD
	if [[ ! -f "$chip_file" ]]; then
		printf "❌ [MODULE 6] File Missing: chip file '%s' not found.\n" "${chip_file}"
=======
	if [[ -n "$chip_file" && -f "/data/$chip_file" ]]; then
		cp "/data/$chip_file" .
	else
		printf "\nError: collapse=%s requires chip file, but it was missing or not found.\n" "$collapse_mode"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
		exit 1
	fi
fi

<<<<<<< HEAD
# unpack and run gsea cli
zip_file="GSEA_LinuxIntel_4.4.0-WithJava.zip"
	if [[ ! -f "GSEA_Linux_4.4.0/gsea-cli.sh" ]]; then
		echo "Unzipping $zip_file..."
		unzip -q "$zip_file"
	fi
=======
zip_file="GSEA_LinuxIntel_4.4.0-WithJava.zip"

if [[ ! -f "GSEA_Linux_4.4.0/gsea-cli.sh" ]]; then
	echo "Unzipping $zip_file..."
	unzip "$zip_file"
fi
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb

# GSEApreranked
if [[ -n "$rnk_file" ]]; then
	if [[ -n "$res_file" || -n "$cls_file" ]]; then
<<<<<<< HEAD
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

	rnk_base=$(basename "${rnk_file%.*}") # remove file extension for name
	results_dir="${rnk_base}.${gmx_prefix}.GseaPreranked"
	if [[ -d "${save_dir}/${results_dir}" ]]; then
		printf "❌ [MODULE 6] Directory conflict: GSEA Preranked results directory already exists for preranked list '%s' and gene set '%s'.\n" "$rnk_base" "$gmx_file"
		printf "Please clean or rename '%s' and rerun analysis.\n" "$save_dir/$results_dir"
		exit 1
	else
		mkdir -p "$results_dir"
	fi

	printf "➡ Running GSEAPreranked...\n"
	./GSEA_Linux_4.4.0/gsea-cli.sh GSEAPreranked -param_file "${param_file}" -collapse "${collapse_mode}" -chip "${chip_file}"
=======
		printf "\nError: For GSEAPreranked, 'res' and 'cls' must NOT be set.\n"
		exit 1
	fi

	# copy required files
	for file in "$rnk_file" "$gmx_file"; do
		if [[ ! -f "/data/$file" && ! -f "/data/gsea/inputs/$file" ]]; then
			printf "\nError: File %s not found in /data or /data/gsea/inputs.\n" "$file"
			exit 1
		fi

		# copy from /gsea after module 5 run, or copy from /data running module 6 alone
		[[ -f "/data/$file" ]] && cp "/data/$file" .
		[[ -f "/data/gsea/inputs/$file" ]] && cp "/data/gsea/inputs/$file" .
	done

	printf "\n➡ Running GSEAPreranked...\n"
	./GSEA_Linux_4.4.0/gsea-cli.sh GSEAPreranked -param_file "${param_file}"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
	
	# rename new directory to include rnk filename
	gsea_result_dir=$(find "${out_dir}" -maxdepth 1 -type d -name "my_analysis.GseaPreranked.*" 2>/dev/null)
	if [[ -n "$gsea_result_dir" ]]; then
<<<<<<< HEAD
		printf "Renamed GSEA Preranked result directory to: %s\n" "$results_dir"
	else
		printf "GSEA produced an error, see report in %s\n" "$out_dir"
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
=======
		rnk_base=$(basename "$rnk_file" | sed 's/\.[^.]*$//')
		new_dir="${out_dir}/${gmx_prefix}.${rnk_base}.GseaPreranked"
		mv "$gsea_result_dir" "$new_dir"
		echo "Renamed GSEA Preranked result directory to: $new_dir"
	fi

# GSEA classic
elif [[ -n "$res_file" && -n "$cls_file" ]]; then
	if [[ -n "$rnk_file" ]]; then
		printf "\nError: For GSEA Classic, 'rnk' must NOT be set.\n"
		exit 1
	fi

	# copy required files
	for file in "$res_file" "$cls_file" "$gmx_file"; do
		if [[ ! -f "/data/$file" && ! -f "/data/gsea/inputs/$file" ]]; then
			printf "\nError: File %s not found in /data or /data/gsea/inputs.\n" "$file"
			exit 1
		fi

		# copy from /gsea after module 5 run, or copy from /data running module 6 alone
		[[ -f "/data/$file" ]] && cp "/data/$file" .
		[[ -f "/data/gsea/inputs/$file" ]] && cp "/data/gsea/inputs/$file" .
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
	done

	label_line=$(sed -n '2p' "$cls_file")
	label_names=$(echo "$label_line" | cut -c3-)
	label_name=$(echo "$label_names" | sed 's/ \+/_vs_/g')
<<<<<<< HEAD
	results_dir="${label_name}.${gmx_prefix}.GseaClassic"
	
	if [[ -d "${save_dir}/${results_dir}" ]]; then
		printf "❌ [MODULE 6] Directory conflict: GSEA Classic results directory already exists (%s).\n" "$save_dir/$results_dir"
		printf "Please clean or rename '%s' and rerun analysis.\n" "$save_dir/$results_dir"
		exit 1
	else
		mkdir -p "$results_dir"
	fi

	printf "➡ Running GSEA Classic...\n"
	./GSEA_Linux_4.4.0/gsea-cli.sh GSEA -param_file "${param_file}" -collapse "${collapse_mode}" -chip "${chip_file}"
=======
	new_dir="${out_dir}/${gmx_prefix}.${label_name}.GseaClassic"

	printf "\n➡ Running GSEA Classic...\n"
	./GSEA_Linux_4.4.0/gsea-cli.sh GSEA -param_file "${param_file}"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb

	# rename new directory to include phenotypes
	gsea_result_dir=$(find "${out_dir}" -maxdepth 1 -type d -name "my_analysis.Gsea.*" 2>/dev/null)
	if [[ -n "$gsea_result_dir" ]]; then
<<<<<<< HEAD
		printf "Renamed GSEA Classic result directory to: %s\n" "$results_dir"
	else
		printf "GSEA produced an error, see report in %s\n" "$out_dir"
		mv "$out_dir" "$save_dir"
		exit 1
	fi
=======
		mv "$gsea_result_dir" "$new_dir"
		printf "Renamed GSEA Classic result directory to: %s\n" "$new_dir"
	fi

>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
# wrong config
else
	printf "\nError: Invalid parameter combination. Provide either:\n"
	printf "   - 'rnk' and 'gmx' only for GSEAPreranked\n"
	printf "   OR\n"
	printf "   - 'res', 'cls', and 'gmx' only for GSEA Classic\n"
	exit 1
fi

<<<<<<< HEAD
# change gsea results directory
mv "$gsea_result_dir" "raw_GSEA_output"
mv "raw_GSEA_output" "$results_dir"
# get reports file for results
report_files=$(find "$results_dir/raw_GSEA_output" -type f -name "gsea_report_*.tsv")
for file in $report_files; do
	cp "$file" "$results_dir/"
done

printf "Processing report files...\n"
fields_results="enrichment_fields.tsv"
./process_reports.sh "${results_dir}" "${fields_results}"

line_count=$(wc -l < "$fields_results")
if (( line_count <= 1 )); then
	printf "⚠️ No statistically significant results in %s\n" "$file"
	cp "$fields_results" "$save_dir/$results_dir"
	exit 0
fi

printf "Getting enriched terms annotations (may take a while)...\n"
./get_terms_annotations.sh "${results_dir}" "$fields_results" "$gmx_file"

files=("$fields_results" enriched_terms_annotations*.tsv)

for file in "${files[@]}"; do
	[[ ! -f "$file" ]] && continue
	cp "$file" "${results_dir}/"
	
	src_col=2
	header=$(head -n 1 "$file")

	mapfile -t sources < <(tail -n +2 "$file" | cut -f "$src_col" | sort -u)
	
	for src in "${sources[@]}"; do
		[[ -z "$src" ]] && continue
		src_dir="${results_dir}/$src"
		mkdir -p "$src_dir"
		{
			printf "%s\n" "$header"
			awk -F'\t' -v col="$src_col" -v val="$src" '$col == val' "$file"
		} > "$src_dir/${src}_${file##*/}" # Stripped path for filename
	done
done

cd "$results_dir" && zip -q -r raw_GSEA_output.zip raw_GSEA_output && rm -rf raw_GSEA_output && cd ..
mv "./${results_dir}" "${save_dir}"
=======
printf "Organizing results directory...\n"
./organize_directory.sh "${new_dir}"
printf "Processing report files...\n"
./process_reports.sh "${new_dir}"
printf "Getting terms annotations...\n"
./get_terms_annotations.sh "${out_dir}" "$gmx_file"	#output=terms_results_file

terms_results_file="$new_dir/terms_annotations_results.csv"
results_files=("$new_dir/short_results.csv" "$new_dir/long_results.csv")

# add source column from termos results file to short and long
for file in "${results_files[@]}"; do
	tmp_name="$new_dir/tmp_name"
	tmp_source="$new_dir/tmp_source"
	tmp_rest="$new_dir/tmp_rest"

	cut -d',' -f1 "$file" > "$tmp_name"
	cut -d',' -f2 "$terms_results_file" > "$tmp_source"
	cut -d',' -f2- "$file" > "$tmp_rest"
	paste -d',' "$tmp_name" "$tmp_source" "$tmp_rest" > "$file.tmp"
	mv "$file.tmp" "$file"
	rm "$tmp_name" "$tmp_source" "$tmp_rest"
done

# organize sources directory
for file in "$new_dir"/*_results.csv; do
	[[ ! -f "$file" ]] && continue
	base_file=$(basename "$file")
	header=$(head -n 1 "$file")
	# unique sources
	mapfile -t sources < <(tail -n +2 "$file" | cut -d',' -f2 | sort -u)
	for source in "${sources[@]}"; do
		[[ -z "$source" ]] && continue
		{
			echo "$header"
			awk -F',' -v col=2 -v val="$source" '$col == val' "$file"
		} > "$new_dir/$source/${source}_$base_file"
	done
done

rm "$new_dir"/*report*
mv "$new_dir" "/data/$out_dir"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
