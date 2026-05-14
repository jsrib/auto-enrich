#!/bin/bash
#set -eo pipefail

config="/data/config"

if [ ! -f "$config" ]; then
	printf "❌ [MAIN] Configuration Error: Pipeline configuration file ('config') not found in set working directory.\n" >&2
	exit 1
else
	sed -i 's/\r$//' $config
	source $config
fi

# check if main variable set
if [[ -z "$modules" ]]; then
	printf "❌ [MAIN] Configuration Error: Variable 'modules' is undefined. Please set it in the 'config' file.\n" >&2
	exit 1
fi

# module numbers:
# 1 = prepare_lists
# 2 = id_mapping_info
# 3 = gprofiler
# 4 = panther
# 5 = prep_gsea_inputs
# 6 = gsea
# 7 = filter_ea_results

# paths
annotations_dir="annotations"
prepared_lists_dir="prepared_gene_lists"
maps_dir="mapped_gene_lists"
gprof_dir="gprofiler"
panther_dir="panther"
gsea_dir="gsea"

# modules run flags
annotations_directory=false
prepare_lists_ran=false
prep_gsea_inputs_ran=false

if [[ -d "/data/$annotations_dir" ]]; then
	printf "[MAIN] Using provided annotations files inside annotations directory...\n"
	annotations_directory=true
else
	printf "[MAIN] Annotations directory NOT found, creating new directory and generating new files.\n"
	mkdir -p "/data/$annotations_dir"
fi

# organism name correspondency index
organism_idx="/data/$annotations_dir/organisms_index"
if [[ ! -f "$organism_idx" || ! -s "$organism_idx" ]]; then
	printf "[MAIN] Organisms Index file not found. Downloading from g:Profiler (https://biit.cs.ut.ee/gprofiler/page/organism-list)...\n"
	url="https://biit.cs.ut.ee/gprofiler/api/util/organisms_list/"

	curl -s "$url" | jq -r '
	(.[0] | keys_unsorted | @tsv), 
	(.[] | map(.) | @tsv)
	' > "$organism_idx"

	if [ $? -eq 0 ]; then
		echo "Success! Data saved to $organism_idx"
	else
		echo "Error: Failed to process the data."
		exit 1
	fi
fi

# handle species name normalization
if [[ -z "${species}" ]]; then
	printf "❌ [MAIN] Configuration Error: Variable 'species' is undefined.\n" >&2
	exit 1
else
	printf "[MAIN] Searching for nomenclature match: '%s'\n" "${species}"
	# $1=display_name, $2=id, $3=scientific_name, $4=taxon
	result=$(awk -F'\t' -v search="${species}" '
		NR > 1 {
			for (i=1; i<=NF; i++) {
				if ($i == search) {
					print $1, $2, $3, $4
					exit 0
				}
			}
		}' OFS='\t' "$organism_idx")

	if [[ -z "$result" ]]; then
		printf "⚠️ [MAIN] No match found for '%s'. Try the exact Scientific Name or TaxonID.\n" "${species}"
	else
		IFS=$'\t' read -r display_name gprof_curl_id scientific_name taxon <<< "$result"
		printf "[MAIN] Match Found!\n"
		printf "   --------------------------------------\n"
		printf "   Common Name: %s\n" "${display_name}"
		printf "   gProf curl ID:   %s\n" "${gprof_curl_id}"
		printf "   Scientific Name:  %s\n" "${scientific_name}"
		printf "   Taxon ID:    %s\n" "${taxon}"
		printf "   --------------------------------------\n"
	fi
fi

# species ids map file
scientific_name=$(echo "$scientific_name" | tr ' ' '_')	# tr '[:upper:]' '[:lower:]'
species_map="/data/$annotations_dir/${scientific_name}_ids_map"

IFS=',' read -ra selected_modules <<< "$modules"
for module in "${selected_modules[@]}"; do
	case "$module" in
		1)	# Module 1 (prepare_lists)
			printf "🚀 [MODULE 1] Initializing: Preparing gene lists using input expression matrix...\n"
			./1_prepare_lists/run.sh "$config"
			if [ $? -eq 0 ]; then
				printf "✅ [MODULE 1] Success: Gene lists generated! Saved in %s.\n" "/data/$prepared_lists_dir"
				prepare_lists_ran=true
			elif [ $? -eq 2 ]; then	# no results found
				printf "⚠️ [MODULE 1] No genes left after set calculations and thresholds."
			else
				printf "❌ [MAIN - MODULE 1] Critical Error: Failed to process expression matrix. Check logs for details.\n" >&2
				exit 1
			fi
			;;

		2)	# Module 2 (map_ids_info) - /prepared_gene_lists directory must be present()
			printf "🚀 [MODULE 2] Initializing: Mapping genes information (GeneID, Uniprot and Symbol)...\n"
			mkdir -p "/data/$maps_dir"

			shopt -s nullglob
			if [[ "$prepare_lists_ran" == true ]]; then
				gene_lists=("/data/$prepared_lists_dir"/*_genes_list)
			else
				gene_lists=("/data/$prepared_lists_dir"/*)
			fi
			shopt -u nullglob

			if [[ ${#gene_lists[@]} -eq 0 ]]; then
				printf "❌ [MODULE 2] Error: No GeneIDs list found in %s.\n" "$prepared_lists_dir" >&2
				exit 1
			fi

			for glist in "${gene_lists[@]}"; do
				basename=$(basename "$glist")
				output="/data/$maps_dir/${basename%.*}_map"
				
				printf "Processing: %s\n" "$basename"
				sed -i 's/\r$//' "$glist"

				./2_gene_mapping/run.sh "${glist}" "${species_map}" "${taxon}"  "${output}"

				status=$?
				if [[ $status -ne 0 && $status -ne 2 ]]; then
					printf "❌ [MAIN - MODULE 2] Critical Error: Failed to map GeneIDs lists. Check logs for details.\n" >&2
					exit 1
				elif [[ $status -eq 2 ]]; then
					printf "⚠️ [MODULE 2] Warning: Mapped list file '%s' already exists. Skipping...\n" "$output"
					continue
				else
					printf "✅ [MODULE 2] Success: Gene list '%s' mapped ! Saved in %s.\n" "$basename" "$output"
				fi
			done
			printf "[MODULE 2] Mapping complete. Check '%s'.!\n\n" "$maps_dir"
			;;

		3) # Module 3 (gProfiler plus) - species and gprofiler dbs variables in config0()
			printf "🚀 [MODULE 3] Initializing: Running Enrichment Analysis with g:Profiler g:GOSt tool...\n"
			gprof_gene_sets="/data/$annotations_dir/${scientific_name}_gProfiler_gene_sets.gmt"

			shopt -s nullglob
			files=(/data/"$maps_dir"/*_map)
			shopt -u nullglob

			if [[ ${#files[@]} -eq 0 || ! -e "${files[0]}" ]]; then
				printf "❌ [MODULE 3] Error: No mapped files found to process in 'mapped_gene_lists'. Make sure to add the '_map' suffix to filenames.\n"
				exit 1
			fi

			printf "Processing %d file(s)...\n" "${#files[@]}"

			for input_map in "${files[@]}"; do
				basename=$(basename "$input_map")
				save_dir="/data/${gprof_dir}/${basename%_map}"
				
				printf "Running gProfiler for: %s\n" "$basename"
				./3_gprofiler_plus/run.sh "${input_map}" "${gprof_curl_id}" "${gprof_gene_sets}" "${save_dir}" "${gprofiler_dbs}"

				status=$?
				case $status in
					0)
						printf "✅ [MODULE 3] Run successful: Significant results stored in '%s'.\n" "$save_dir"
						;;
					2)
						printf "⚠️ [MODULE 3] Run Completed: No significant results found for '%s' list.\n" "$basename"
						;;
					*)
						printf "❌ [MAIN - MODULE 3] Critical Error: gProfiler run failed. Check logs for details.\n" >&2
						exit 1
						;;
				esac
			done
			printf "✅ [MODULE 3] Complete: gProfiler analysis finished. Check 'gprofiler/results' for results!\n\n"
			;;

		4) # Module 4 (PANTHER plus) - species and gprofiler dbs variables in config0()
			printf "🚀 [MODULE 4] Initializing: Running PANTHER enrichment analysis...\n"
			panther_gene_sets="/data/$annotations_dir/${scientific_name}_PTHR19.0_gene_sets.gmt"
			reactome_gene_sets="/data/$annotations_dir/${scientific_name}_REAC_pathways.gmt"
			gos_gene_sets="/data/$annotations_dir/${scientific_name}_go_terms.gmt"

			shopt -s nullglob
			files=(/data/"$maps_dir"/*_map)
			shopt -u nullglob

			if [[ ${#files[@]} -eq 0 || ! -e "${files[0]}" ]]; then
				printf "❌ [MODULE 4] Error: No mapped files found to process in '%s'.\n" "$maps_dir"
				exit 1
			fi

			printf "Processing %d file(s)...\n" "${#files[@]}"

			for input_map in "${files[@]}"; do
				basename=$(basename "$input_map")
				save_dir="/data/${panther_dir}/${basename%_map}"

				printf "Running PANTHER for: %s\n" "$basename"
				./4_panther_plus/run.sh "${input_map}" "${taxon}" "${save_dir}" "${panther_gene_sets}" "${reactome_gene_sets}" "${gos_gene_sets}" "${species_map}" "${panther_dbs}"

				status=$?
				case $status in
					0)
						printf "✅ [MODULE 4] Run successful: Significant results stored in '%s'.\n" "$save_dir"
						;;
					2)
						printf "⚠️ [MODULE 4] Run Completed: No significant results found for '%s'.\n" "$basename"
						;;
					*)
						printf "❌ [MAIN - MODULE 4] Critical Error: PANTHER run failed for '%s'. Check logs.\n" "$basename" >&2
						exit 1
						;;
				esac
			done
			printf "✅ [MODULE 4] Complete: PANTHER analysis finished. Check 'panther/results' for results!\n\n"
			;;

		5) # Module 5 (Prep GSEA inputs) - mandatory config5 ()
			printf "🚀 [MODULE 5] Initializing: Preparing GSEA inputs\n"
			save_dir="/data/${gsea_dir}"
			./5_prep_gsea_inputs/run.sh "$config" "$save_dir"
			if [[ $? -ne 0 ]]; then
				printf "❌ [MAIN - MODULE 5] Critical Error: GSEA input preparation failed. Check logs for details.\n" >&2
				exit 1
			fi

			prep_gsea_inputs_ran=true
			printf "✅ [MODULE 5] GSEA inputs prepared successfully. Saved under %s\n" "$save_dir"
			;;

		6) # GSEA plus - mandatory gsea_parameters file()
			printf "🚀 [MODULE 6] Initializing: Running Gene Set Enrichment Analysis (GSEA)...\n"
			input_dir="/data"
			gene_sets_dir="/data/gene_sets"
			save_dir="/data/${gsea_dir}/results"

			declare -A parameters(
				# essencial
				[res]=""					# classic
				[cls]=""					# classic
				[rnk]=""					# preranked
				[gmx]=""					# gene sets file (gmt)
				[out]="results"				# pipeline default: results
				[rpt_label]=""
				# analysis parameters
				[perm]=""					# classic = phenotype, preranked = gene_set
				[nperm]=""				# number of permutations (default: 1000)
				[scoring_scheme]=""			# enrichment statistic (classic, default: weighted, weighted_p2, signal2noise)
				[norm]=""					# normalization method
				[set_max]=""				# max gene set size
				[set_min]=""				# min gene set size
				# chip and collapse parameters
				[chip]=""					# chip file
				[collapse]=""				# collapse method (default: collapse, no_collapse, remap_only)
				# visualization and report
				[plot_top_x]=1000			# number of top gene sets to plot in results (gsea default: 20)
				[make_sets]=""
				[gui]="false"
				[save_details]="false"
				# anymore parameters? see GSEA documentation
			)

			if [[ "$scientific_name" != "Homo sapiens" ]] && [[ "$scientific_name" != "Mus musculus" ]]; then
				printf "❌ [MODULE 6] Invalid Species: For GSEA only 'Homo sapiens' and 'Mus musculus' are supported. Please specify a valid species.\n" >&2
				exit 1
			fi

			if [[ -z "$method" ]]; then
				printf "❌ [MODULE 6] Configuration Error: Variable 'method' is undefined or empty. Please specify 'classic' or 'preranked'.\n" >&2
				exit 1
			fi

			# create gsea directory if doesnt exist
			if [[ -d "/data/$gsea_dir" ]]; then
				mkdir -p "/data/$gsea_dir"
			fi

			# handle gmx file generation or take as input set in gmx var
			if [[ -n "$gmx" ]]; then
				parameters["gmx"]="${gene_sets_dir}/$(basename "$gmx")"
			else
				# Error if the directory doesn't exist OR if it exists but is empty
				if [[ ! -d "$gene_sets_dir" || -z "$(ls -A "$gene_sets_dir" 2>/dev/null)" ]]; then
					printf "❌ [MODULE 6] Error: Gene sets directory '%s' is missing or empty, and 'gmx' is not specified.\n" "$gene_sets_dir" >&2
					printf "Please define the 'gmx' variable or provide gene set files in the directory.\n" >&2
					exit 1
				else
					combined_genesets="/data/${gsea_dir}/combined_gene_sets.gmx"
					cat "$gene_sets_dir/*" >> "$combined_genesets"
					parameters["gmx"]="$combined_genesets"
				fi
			fi

			# handle chip file generation by default or take as input if collapse method specified in config
			if [[ -n "$collapse" && -z "$chip" ]]; then
				if [[ $collapse == "Collapse" ]] || [[ $collapse == "Remap_Only" ]]; then
					printf "❌ [MODULE 6] Configuration Error: 'collapse' method specified without a 'chip' file. Please provide a chip file to use collapse.\n" >&2
					exit 1
				else
					if [[ ! -f ${chip} ]]; then
						printf "❌ [MODULE 6] Configuration Error: Specified chip file '%s' not found.\n" "$chip" >&2
						exit 1
					fi
					parameters["collapse"]="$collapse"
					parameters["chip"]="${chip}"
				fi
			fi
			# else
				# default pipeline behavior is to use collapse with self-generated chip file to map geneIDS into gene symbols
				# parameters["collapse"]="Collapse"
				# ---------- build script to generate chip file from species map file ----------
				# ./6_gsea_plus/generate_chip_file.sh
				# chip_file="/data/${gsea_dir}/chip_set_file.chip"
				# parameters["chip"]="${chip_file}"
			# fi

			case "$method" in
				classic)
					run_file="/data/${gsea_dir}/gsea_classic_parameters"
					parameters["perm"]="phenotype"
					if [[ "$prep_gsea_inputs_ran" == true ]]; then
						printf "Using prepared inputs (method = '%s')\n" "$method"
						printf "Running GSEA Classic with prepared inputs...\n"
						inputs_dir="/data/${gsea_dir}/classic_inputs"
						# cp $run_file "${inputs_dir}/run_parameters"
						parameters["res"]="${inputs_dir}/expression_dataset.gct"
						parameters["cls"]="${inputs_dir}/phenotype_labels.cls"
					else
						if [[ -n "$res" && -n "$cls" ]]; then
							parameters["res"]="/data/${res}"
							parameters["cls"]="/data/${cls}"
							printf "Running GSEA Classic with provided .gct and .cls files...\n"
							#cp "/data/${res}" /data/${gsea_dir}/
							#cp "/data/${cls}" /data/${gsea_dir}/
						else
							printf "❌ [MODULE 6] Configuration Error: For 'classic' method, if not running module 5 (prepare gsea inputs), you must configure and provide both 'res' and 'cls' files.\n" >&2
							exit 1
						fi
					fi
					# fill any left over empty parameters set in the config by the user
					for key in "${!parameters[@]}"; do
						if [[ -z "${parameters[$key]}" && -n "${!key}" ]]; then
							parameters["$key"]="${!key}"
						fi
					done
					# set up the config file for this run
					> $run_file
					for key in "${!parameters[@]}"; do
						value="${parameters[$key]}"
						# only write non-empty parameters
						if [[ -n "$value" ]]; then
							printf "%s\t%s\n" "$key" "$value" >> "$run_file"
						fi
					done
					printf "Parameter file written to: %s\n" "$run_file"
					./6_gsea_plus/run.sh "$run_file" "${save_dir}"
					if [[ $? -ne 0 ]]; then
						printf "❌ [MAIN - MODULE 6] Critical Error: GSEA Preranked run failed. Check logs for details.\n" >&2
						exit 1
					fi
				;;
				preranked)
					shopt -s nullglob
					parameters["perm"]="gene_set"
					rnk_files=()
					if [[ "$prep_gsea_inputs_ran" == true ]]; then
						printf "Using prepared inputs (method = '%s')\n" "$method"
						inputs_dir="/data/${gsea_dir}/preranked_lists"
						printf "Running GSEAPreranked for prepared preranked files in '%s'...\n" "${inputs_dir}"
						rnk_files=("$inputs_dir"/*.rnk)
					elif [[ -n "$rnk" ]]; then
						printf "Running GSEAPreranked for provided preranked file '%s'...\n" "${parameters["rnk"]}"
						# check in /data and in /data/preranked_lists for the provided file
						rnk_files=("/data/${rnk}")
						if [[ ! -f "${rnk_files[0]}" ]]; then
							rnk_files="/data/preranked_lists/${rnk}"
							if [[ ! -f "${rnk_files[0]}" ]]; then
								printf "❌ [MODULE 6] Configuration Error: Provided preranked file '%s' not found in /data nor in /data/preranked_lists.\n" "${rnk}" >&2
								exit 1
							fi
						fi
					else
						inputs_dir="/data/preranked_lists"
						printf "Running GSEAPreranked for all .rnk files in '%s'...\n" "${inputs_dir}"
						rnk_files=("$inputs_dir"/*)
					fi
					shopt -u nullglob

					# run GSEApreranked for each rnk file found
					if [[ ${#rnk_files[@]} -gt 0 ]]; then
						for rnk in "${rnk_files[@]}"; do
							[[ ! -f "$rnk" ]] && continue
							parameters["rnk"]="$rnk"
							base_name=$(basename "$rnk" .rnk)
							# ------ needs testing
							# parameters["rpt_label"]="GSEA_${base_name}"
							printf "Processing: %s\n" "$base_name"
							run_file="/data/${gsea_dir}/gsea_${base_name}_preranked_parameters"
							# fill any left over empty parameters set in the config by the user
							for key in "${!parameters[@]}"; do
								if [[ -z "${parameters[$key]}" && -n "${!key}" ]]; then
									parameters["$key"]="${!key}"
								fi
							done
							# set up the config file for this run
							> $run_file
							for key in "${!parameters[@]}"; do
								value="${parameters[$key]}"
								# only write non-empty parameters
								if [[ -n "$value" ]]; then
									printf "%s\t%s\n" "$key" "$value" >> "$run_file"
								fi
							done
							printf "Parameter file written to: %s\n" "$run_file"
							./6_gsea_plus/run.sh "$run_file" "${save_dir}"
							if [[ $? -ne 0 ]]; then
								printf "❌ [MAIN - MODULE 6] Critical Error: GSEA Preranked run failed. Check logs for details.\n" >&2
								exit 1
							fi
						done
					else
						printf "❌ [MODULE 6] Configuration Error: No preranked (.rnk) files found to process.\n" "${inputs_dir}" >&2
						exit 1
					fi
				*)
					printf "❌ [MODULE 6] Configuration Error: Invalid method '%s'. Please specify 'classic' or 'preranked'.\n" "$method" >&2
					exit 1
				;;
			esac
			printf "✅ [MODULE 6] GSEA Preranked run completed successfully with significant results.\n"

			# else
			# 	printf "➡️ Running GSEA using manually provided gsea_parameters file...\n"
			# 	param_file="/data/${gsea_dir}/$(basename "$gsea_parameters")"
			# 	for key in res cls rnk gmx; do
			# 		val=$(awk -F'\t' -v k="$key" '$1 == k { print $2 }' "$param_file")
			# 		if [[ -n "$val" && -f "/data/$val" ]]; then
			# 			cp "/data/$val" "/data/${gsea_dir}/"
			# 		else
			# 			printf "Error: No %s file found in /data to run GSEA\n" "$val"
			# 		fi
			# 	done

			# 	./6_gsea_plus/run.sh "$param_file"
			# 	if [[ $? -ne 0 ]]; then
			# 		printf "❌ GSEA run failed.\n"
			# 		exit 1
			# 	else
			# 		printf "✅ GSEA Plus completed.\n"
			# 		results_dir=$(awk -F'\t' '$1 == "out" { print $2 }' "$param_file")
			# 		save_dir="/data/$gsea_dir/$results_dir"
			# 		if [[ ! -d "$save_dir" ]]; then
			# 			mkdir -p "$save_dir"
			# 		fi
			# 		# organize results
			# 		if [[ -n "$results_dir" && -d "/data/$results_dir" ]]; then
			# 			mv /data/"$results_dir"/* "$save_dir"
			# 			printf "Moved results directory '%s' into GSEA directory.\n" "$results_dir"
			# 			rm -r /data/"$results_dir"
			# 		else
			# 			printf "Warning: results directory not found or not specified.\n"
			# 		fi
			# 	fi
			# fi
			;;

		7) # Module 7 (Filter EA results) - mandatory filtering parametes in config0()
			printf "🚀 [MODULE 7] Initializing: Filtering Enrichment Analysis Annotations results\n"

			# set tools directory and structure
			declare -A TOOL_DIRS=(
				["gProfiler"]="$gprof_dir"
				["PANTHER"]="$panther_dir"
				["GSEA"]="$gsea_dir"
			)
			declare -A TOOL_TYPES=(
				["gProfiler"]="per-map"
				["PANTHER"]="per-map"
				["GSEA"]="flat"
			)

			# find subdirectory lists resutls
			find_gene_maps() {
				local dir=$1
				local found=()
				if [[ -d "$dir" ]]; then
					for path in "$dir"/*/results; do
						[[ -d "$path" ]] && found+=("$(basename "$(dirname "$path")")")
					done
				fi
				echo "${found[@]}"
			}

			# find gsea results subdirs
			find_gsea_subdirs() {
				local dir=$1
				local found=()
				if [[ -d "$dir/results" ]]; then
					for sub in "$dir/results"/*/; do
						[[ -d "$sub" ]] && found+=("$(basename "$sub")")
					done
				fi
				echo "${found[@]}"
			}

			#look for results csv
			has_results_csv() {
				local dir=$1
				find "$dir" -type f -name "terms_annotations_results.csv" | grep -q .
			}

			# process all tools
			process_tool() {
				local name=$1
				local base_dir=$2
				local mode=$3

				printf "\nFiltering %s results...\n" "$name"

				if [[ "$mode" == "flat" ]]; then
					local subdirs=()
					read -ra subdirs <<< "$(find_gsea_subdirs "$base_dir")"
					if [[ ${#subdirs[@]} -eq 0 ]]; then
						printf "⚠️  No subdirectories found inside %s/results\n" "$base_dir"
						return
					fi
					for sub in "${subdirs[@]}"; do
						local results_dir="${base_dir}/results/${sub}"
						if [[ -f "$results_dir/terms_annotations_results.csv" ]]; then
							run_filter "$results_dir" "$name" "$sub"
						else
							printf "⚠️  No results CSV found in %s\n" "$results_dir"
						fi
					done
				else
					local maps=()
					read -ra maps <<< "$(find_gene_maps "$base_dir")"
					if [[ ${#maps[@]} -eq 0 ]]; then
						printf "⚠️ No gene maps found in %s\n" "$base_dir"
						return
					fi
					for map in "${maps[@]}"; do
						local base_name="${map%_map}"  # strip _map suff
						local results_dir="${base_dir}/${map}/results"
						if [[ -f "$results_dir/terms_annotations_results.csv" ]]; then
							run_filter "$results_dir" "$name" "$base_name"
						else
							printf "⚠️ No results CSV found in %s\n" "$results_dir"
						fi
					done
				fi
			}

			run_filter() {
				local results_dir=$1
				local tool=$2
				local target=$3

				if [[ ! -f "$results_dir/terms_annotations_results.csv" ]]; then
					printf "⚠️  No 'terms_annotations_results.csv' found in %s\n" "$results_dir"
					return
				fi

				local rel_path="${results_dir#/data/}"
				local tool_args="${rel_path}"
				[[ -n "$max_occur" ]] && tool_args+=" --max-occurrence $max_occur"
				[[ -n "$max_annot" ]] && tool_args+=" --max-annotations $max_annot"
				[[ -n "$min_ratio" ]] && tool_args+=" --min-ratio $min_ratio"

				./7_filter_ea_results/run.sh $tool_args
				if [[ $? -eq 0 ]]; then
					printf "✅ %s results filtered successfully (%s).\n" "$tool" "$target"
				else
					printf "❌ Error: Filtering %s results failed (%s).\n" "$tool" "$target"
					exit 1
				fi
			}

			# run or pre-run enrichment results process
			any_processed=false
			for tool in "${!TOOL_DIRS[@]}"; do
				tool_dir="/data/${TOOL_DIRS[$tool]}"
				tool_mode="${TOOL_TYPES[$tool]}"
				if [[ -d "$tool_dir" ]] && has_results_csv "$tool_dir"; then
					process_tool "$tool" "$tool_dir" "$tool_mode"
					any_processed=true
				fi
			done

			if [[ "$any_processed" == false ]]; then
				printf "❌ No enrichment analysis results found to filter.\n"
				exit 1
			fi
			;;

		# 8) # Module 8 (build plots) - necessary variables on config0 file()
		# 	printf "\nRunning tool 8 (Build Plots) - Building enriched terms counts plots and presence matrices\n"
		# 	config="/data/config0"
		# 	./8_build_plots/run.sh "$config"
		# 	target="/plots_and_gene_matrices/$method"
		# 	if [[ $? -eq 0 ]]; then
		# 		printf "✅ Plots and gene matrices built successfully (%s).\n" "$target"
		# 	else
		# 		printf "❌ Error: Plotting results failed (%s).\n" "$target"
		# 		exit 1
		# 	fi
	esac
done

# ---- Additional flags -----
# gene_occurences file, only if flag set to y, else dont create file
# gene_occurrences="${gene_occurrences,,}"
# if [[ "$gene_occurrences" == "y" ]]; then
# 	for method in gprofiler panther gsea; do
# 		method_dir="/data/$method"
# 		if [[ -d "$method_dir" ]]; then
# 			printf "Generating gene occurences files for %s.\n" "$method"
# 			./flags/gene_occurrences.sh "$method_dir"
# 		fi
# 	done
# 	printf "Finished\n"
# else
# 	# common misspellings
# 	case "$gene_occurrences" in
# 		"gene_occurences"|"gene_ocurences"|"gene_ocurrences")
# 			printf "Warning: Did you mean 'gene_occurrences'? Flag ignored.\n"
# 			;;
# 	esac
# fi

# # build reactome hierarchy files (just for REAC dataset)
# if [[ "$reac_hierarchy" == "y" ]]; then
# 	for method in gprofiler panther; do
# 		method_dir="/data/$method"
# 		if [[ -d "$method_dir" ]]; then
# 			printf "Generating REACTOME hierarchy trees for %s.\n" "$method"
# 			source ./4_panther_plus/normalize_name.sh "${species}"
# 			if [[ -z "$long_name" ]]; then
# 				printf "Input species '%s' not found.\n" "${species}"
# 				exit 1
# 			fi
# 			./flags/reactome_tree/run.sh "$method_dir" "$long_name"
# 		fi
# 	done
# 	printf "Finished\n"
# fi
