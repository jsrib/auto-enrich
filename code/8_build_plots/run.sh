#!/bin/bash
cd /opt/8_build_plots

if [[ $# -ne 1 ]]; then
	printf "Usage: %s <config0>\n" "$0"
	exit 1
fi

config="$1"
source $config
out_dir="/data/plots_and_gene_matrices/${method}"

if [ -d "${out_dir}" ]; then
	printf "Warning: Results Directory %s, cannot replace existing.\n" "$out_dir"
	exit 1
else
	mkdir -p $out_dir
	cp plot.py $out_dir/
fi

# indirect input: used gene lists for enrichment results
printf "Preparing necessary files...\n"
if [[ "$dir" == "standard" ]] && [[ -d "/data/prepared_gene_lists" ]]; then
	printf "Using prepared_gene_lists (standard)\n"
	ls /data/prepared_gene_lists > list_tmp1
elif [[ -d "/data/$dir" ]]; then
	printf "Using data from %s\n" "$dir"
	ls "/data/$dir" > list_tmp1
else
	printf "Error: Lists directory '%s' not found in /data.\n" "$dir"
	exit 1
fi

awk -v order="$order" -v sep="$field_separator" '
BEGIN {
    n = split(order, arr, " ");
    for (i = 1; i <= n; i++) map[arr[i]] = i;
}

{
    tag = "";
    if (sep == "" || sep == "NULL") {	#single elements
        key = $0
        if (key in map) tag = map[key] "#" key
        else tag = "999#" key
        print tag
    }
    else {
        nf = split($0, parts, sep)	#split by filename
        for (i = 1; i <= nf; i++) {
            key = parts[i]
            if (key in map)
                tag = tag (i == 1 ? "" : sep) map[key] "#" key
            else
                tag = tag (i == 1 ? "" : sep) "999#" key
        }
        print tag
    }
}
' list_tmp1 |
sort -t'#' -k1,1n |
awk -F'#' -v sep="$field_separator" '
{
    out = ""
    nf = split($0, parts, "#")
    for (i = 2; i <= nf; i += 2) {
        out = (out == "" ? parts[i] : out sep parts[i])
    }
    print out
}' > sample_list

# indirect input: enrichment results files
mkdir -p select
while read -r slist; do
	if [ "$method" == "panther" ]; then
		files=(/data/panther/*"$slist"*/results/terms_annotations_results.csv)
	elif [ "$method" == "gprofiler" ]; then
		files=(/data/gprofiler/*"$slist"*/results/terms_annotations_results.csv)
	else
		echo "Error: Unknown method '$method'"
		exit 1
	fi

	if [[ ! -e "${files[0]}" ]]; then
		echo "Error: No enrichment file found for sample '$slist' with method '$method'."
		exit 1
	fi

	for file in "${files[@]}"; do
		cp "$file" "./select/$slist"
	done
done < sample_list

# get all unique term ids
cat ./select/* | cut -f1 -d',' | grep -v -e '^TermID$' -e '^null$' | awk 'NF' | sort -u > tmp4

# indirect input: mapped gene lists
map_dir="/data/mapped_gene_lists"
if [[ ! -d "$map_dir" ]]; then
	printf "Error: Mapped gene lists directory 'mapped_gene_lists' not found in /data.\n"
	exit
fi

declare -A gene_maps
while read -r sample; do
	for file in "$map_dir"/*"$sample"*; do
		[ -e "$file" ] || continue	# skip no match
		while read -r _ _ symbol _; do
			gene_maps["$sample|$symbol"]=1
		done < "$file"
	done
done < sample_list

printf "Processing terms, building counts, members, plots, and gene matrices...\n"
while read -r term; do
	mapfile -t term_lines < <(grep -h "^$term," ./select/*)
	[[ ${#term_lines[@]} -eq 0 ]] && continue  # skip if no hits
	first_line="${term_lines[0]}"
	if [[ "$method" == "panther" ]]; then
		name=$(printf "%s" "$first_line" | cut -d',' -f2)
		signal=$(printf "%s" "$first_line" | cut -d',' -f4)
		source=$(printf "%s" "$first_line" | cut -d',' -f3)
		genes_field=$(printf "%s" "$first_line" | cut -d',' -f10)
	elif [[ "$method" == "gprofiler" ]]; then
		name=$(printf "%s" "$first_line" | cut -d',' -f2)
		signal=""
		source=$(printf "%s" "$first_line" | cut -d',' -f3)
		genes_field=$(printf "%s" "$first_line" | cut -d',' -f8)
	else
		printf "Error: Unkown method '%s'\n" "$method"
		exit 1
	fi

	safe_term="${term//[:\/]/_}"
	safe_name=$(printf "%s" "$term $name" | tr -cs '[:alnum:] _-' ' ')
	safe_source=$(printf "%s" "$source" | tr -cs '[:alnum:]_-' ' ')
	
	# set final target dir
	target_dir="$out_dir/$safe_source/$safe_name/"
	mkdir -p "$target_dir"

# ------- Build counts file -------
	out_counts="$out_dir/counts_$safe_term"
	printf "%s\n" "$term" > "$out_counts"
	printf "%s\n" "$name" >> "$out_counts"
	printf "%s\n" "$signal" >> "$out_counts"
	printf "%s\n" "$source" >> "$out_counts"
	printf "\n" >> "$out_counts"
	printf "Files where the term is enriched\n" >> "$out_counts"
	printf "\n" >> "$out_counts"

	mapfile -t enriched_samples < <(grep -l "$term" ./select/* | cut -d'/' -f3)
	while read -r sample; do
		if printf '%s\n' "${enriched_samples[@]}" | grep -qx "$sample"; then
			printf "%s\n" "$sample" >> "$out_counts"
		fi
	done < sample_list
	printf "\n" >> "$out_counts"

	IFS=' ;' read -r -a term_genes <<< "${genes_field//; / }"
	members=${#term_genes[@]}
	printf "Number of members %s\n" "$members" >> "$out_counts"

	# count overlaps per sample
	declare -A sample_counts
	for sample in $(cat sample_list); do
		count=0
		intersect_genes=()
		for gene in "${term_genes[@]}"; do
			[[ -n "${gene_maps["$sample|$gene"]:-}" ]] && ((count++))
		done
		sample_counts[$sample]=$count
	done

	for sample in $(cat sample_list); do
		printf "%s %s\n" "$sample" "${sample_counts[$sample]:-0}" >> "$out_counts"
	done

# ------- Build members files for term -------
	out_members="$out_dir/members_$safe_term"
	> "$out_members"
	for sample in $(cat sample_list); do
		intersect_genes=()
		for gene in "${term_genes[@]}"; do
			[[ -n "${gene_maps["$sample|$gene"]}" ]] && intersect_genes+=("$gene")
		done

		if (( ${#intersect_genes[@]} > 0 )); then		# no genes intersect = 0
			printf "%s\t%s\n" "$sample" "${intersect_genes[*]}" >> "$out_members"
		else
			printf "%s\t0\n" "$sample" >> "$out_members"
		fi
	done

# ------- Gene matrix per term with member counts -------
	out_matrix="$out_dir/gene_matrix_$safe_term"
	genes=($(awk '{for(i=2;i<=NF;i++) if($i!="0") g[$i]=1} END {for(x in g) print x}' "$out_members" | sort))
	{
		printf "Sample\t#Members"
		for g in "${genes[@]}"; do printf "\t%s" "$g"; done
		printf "\n"
	} > "$out_matrix"

	declare -A gene_totals
	for g in "${genes[@]}"; do
		gene_totals[$g]=0
	done

	while read -r line; do
		sample=$(printf "%s" "$line" | cut -f1)
		present_genes=($(printf "%s" "$line" | cut -f2-))
		declare -A gene_map
		for g in "${present_genes[@]}"; do gene_map[$g]=1; done
		if [[ "${present_genes[0]}" != "0" ]]; then
			for g in "${present_genes[@]}"; do gene_map[$g]=1; done
			member_count=${#present_genes[@]}
		else
			member_count=0
		fi

		# fill matrix
		printf "%s\t%s" "$sample" "$member_count" >> "$out_matrix"
		for g in "${genes[@]}"; do
			if (( member_count == 0 )); then
				printf "\t0" >> "$out_matrix"
			elif [[ -n "${gene_map[$g]:-}" ]]; then
				printf "\t1" >> "$out_matrix"
				((gene_totals[$g]++))
			else
				printf "\t0" >> "$out_matrix"
			fi
		done
		printf "\n" >> "$out_matrix"
		unset gene_map
	done < "$out_members"

	{
		printf "Total occurrences\t-"
		for g in "${genes[@]}"; do
			printf "\t%s" "${gene_totals[$g]}"
		done
		printf "\n"
	} >> "$out_matrix"

	unset gene_totals

# ------- Build the Plot -------
	plots_dir="$out_dir/$safe_source/0_plots/"
	mkdir -p "$plots_dir"

	awk '/Number of members/ {found=1; next} found' "$out_counts" > "$out_dir/tmp_term"
	if [ -s "$out_dir/tmp_term" ]; then
		pushd "$out_dir" >/dev/null
		graph_title="$term ${name// /_} $source $signal #$members"
		python3 plot.py "$graph_title"
		if [ -f my_plot.pdf ]; then
			plot_name="linechart_${safe_term}_${safe_name}_${source}_${signal}_${members}.pdf"
			cp my_plot.pdf "$target_dir/${plot_name}.pdf"
			mv my_plot.pdf "$plots_dir/${plot_name}.pdf"
		else
			echo "Warning: my_plot.pdf not created for term $term"
		fi
		popd >/dev/null
	fi
	[ -f "$out_dir/tmp_term" ] && rm "$out_dir/tmp_term"

	python3 matrix.py "$out_matrix" "$graph_title"
	matrix_name="matrix_${safe_term}_${safe_name}_${db}_${signal}_${members}"
	cp my_matrix.pdf "$target_dir/${matrix_name}.pdf"
	mv my_matrix.pdf "$plots_dir/${matrix_name}.pdf"

# ------- Organize out_directory -------
	mv "$out_counts" "$target_dir"
	mv "$out_matrix" "$target_dir"
	mv "$out_members" "$target_dir"
done < tmp4

rm $out_dir/plot.py

