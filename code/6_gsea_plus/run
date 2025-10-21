#!/bin/bash
# GSEA plus Module 6
cd /opt/6_gsea_plus
set -euo pipefail

if [ $# -ne 1 ]; then
	printf "Usage: %s <gsea_parameters>\n" "$0"
	exit 1
fi

param_file="$1"

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
	printf "\nError: 'gmx' parameter is required.\n"
	exit 1
else
	# prefix for output dir name
	gmx_base=$(basename "$gmx_file")
	gmx_prefix=$(echo "$gmx_base" | sed -E 's/\.v[0-9]+\.[0-9]+.*//')
fi

if [[ ! -d "/data/$out_dir" ]]; then
	mkdir -p "/data/$out_dir"
fi

# handle chip file, only necessary if collapse ON
if [[ "$collapse_mode" == "Collapse" || "$collapse_mode" == "Remap_Only" ]]; then
	if [[ -n "$chip_file" && -f "/data/$chip_file" ]]; then
		cp "/data/$chip_file" .
	else
		printf "\nError: collapse=%s requires chip file, but it was missing or not found.\n" "$collapse_mode"
		exit 1
	fi
fi

zip_file="GSEA_LinuxIntel_4.4.0-WithJava.zip"

if [[ ! -f "GSEA_Linux_4.4.0/gsea-cli.sh" ]]; then
	echo "Unzipping $zip_file..."
	unzip "$zip_file"
fi

# GSEApreranked
if [[ -n "$rnk_file" ]]; then
	if [[ -n "$res_file" || -n "$cls_file" ]]; then
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
	
	# rename new directory to include rnk filename
	gsea_result_dir=$(find "${out_dir}" -maxdepth 1 -type d -name "my_analysis.GseaPreranked.*" 2>/dev/null)
	if [[ -n "$gsea_result_dir" ]]; then
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
	done

	label_line=$(sed -n '2p' "$cls_file")
	label_names=$(echo "$label_line" | cut -c3-)
	label_name=$(echo "$label_names" | sed 's/ \+/_vs_/g')
	new_dir="${out_dir}/${gmx_prefix}.${label_name}.GseaClassic"

	printf "\n➡ Running GSEA Classic...\n"
	./GSEA_Linux_4.4.0/gsea-cli.sh GSEA -param_file "${param_file}"

	# rename new directory to include phenotypes
	gsea_result_dir=$(find "${out_dir}" -maxdepth 1 -type d -name "my_analysis.Gsea.*" 2>/dev/null)
	if [[ -n "$gsea_result_dir" ]]; then
		mv "$gsea_result_dir" "$new_dir"
		printf "Renamed GSEA Classic result directory to: %s\n" "$new_dir"
	fi

# wrong config
else
	printf "\nError: Invalid parameter combination. Provide either:\n"
	printf "   - 'rnk' and 'gmx' only for GSEAPreranked\n"
	printf "   OR\n"
	printf "   - 'res', 'cls', and 'gmx' only for GSEA Classic\n"
	exit 1
fi

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
