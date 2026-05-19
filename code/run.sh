#!/bin/bash
set -eo pipefail

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

# species ids map file (required in various modules, best to always have it)
scientific_name=$(echo "$scientific_name" | tr ' ' '_')	# tr '[:upper:]' '[:lower:]'
species_map="/data/$annotations_dir/${scientific_name}_ids_map"
basename=$(basename "$species_map")
if [ ! -s "$species_map" ]; then
	printf "File '%s' not found, creating new one...\n" "$basename"
	./2_gene_mapping/id_uniprot_symbol_mapping.sh "$taxon" "${species_map}"
	printf "Species ids map file saved under '%s'...\n" "$species_map"
fi

# selected modules interation
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

		3) # Module 3 (gProfiler plus) - mapped_gene_lists directory in /data, species and gprofiler dbs variables in config()
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
			printf "[MODULE 3] Complete: gProfiler analysis finished. Check 'gprofiler/results' for results!\n\n"
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
			printf "[MODULE 4] Complete: PANTHER analysis finished. Check 'panther/results' for results!\n\n"
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
			inputs_dir="/data"
			gene_sets_dir="/data/gene_sets"
			save_dir="/data/${gsea_dir}/results"
			# gsea run directory, where files must be for the run, in config only declared filenames (not paths)
			run_dir="/opt/6_gsea_plus"

			declare -A parameters=(
				# essencial
				[res]=""					# classic
				[cls]=""					# classic
				[rnk]=""					# preranked
				[gmx]=""					# gene sets file (gmt)
				[out]="results"				# pipeline default: results
				[rpt_label]=""
				# analysis parameters
				[permute]=""					# classic = phenotype, preranked = gene_set
				[nperm]=""				# number of permutations (default: 1000)
				[scoring_scheme]=""			# enrichment statistic (classic, default: weighted, weighted_p2, signal2noise)
				[norm]=""					# normalization method
				[set_max]=""				# max gene set size
				[set_min]=""				# min gene set size
				# chip and collapse parameters
				[chip]=""					# chip file
				[collapse]=""				# collapse method (default: collapse, no_collapse, remap_only)
				# visualization and report
				[plot_top_x]=1000			# number of top gene sets to plot in results (this also generates the 'core enrichment' genes <=> "genes_in_intersection"). pipeline default: 5000; gsea default: 20
				[make_sets]=""
				#[gui]="false"
				#[save_details]="false"
				# anymore parameters? see GSEA documentation
			)

			if [[ "${scientific_name}" != "Homo_sapiens" ]] && [[ "${scientific_name}" != "Mus_musculus" ]]; then
				printf "❌ [MAIN] Invalid Species: For GSEA only 'Homo sapiens' and 'Mus musculus' are supported (%s). Please specify a valid species.\n" >&2 "${scientific_name}"
				exit 1
			fi

			if [[ -z "$method" ]]; then
				printf "❌ [MAIN] Configuration Error: Variable 'method' is undefined or empty. Please specify 'classic' or 'preranked'.\n" >&2
				exit 1
			fi

			# create gsea directory if doesnt exist
			if [[ ! -d "/data/$gsea_dir" ]]; then
				mkdir -p "/data/$gsea_dir"
			fi

			# handle gmx file generation or take as input set in gmx var
			if [[ -n "$gmx" ]]; then
				cp "${gene_sets_dir}/$(basename "${gmx}")" "${run_dir}/"
				parameters["gmx"]="$(basename "${gmx}")"
			else
				# Error if the directory doesn't exist OR if it exists but is empty
				if [[ ! -d "$gene_sets_dir" || -z "$(ls -A "$gene_sets_dir" 2>/dev/null)" ]]; then
					printf "❌ [MAIN] Error: Gene sets directory '%s' is missing or empty, and 'gmx' is not specified.\n" "$gene_sets_dir" >&2
					printf "Please define the 'gmx' variable or provide gene set files in the directory.\n" >&2
					exit 1
				else
					if [[ "${scientific_name}" == "Mus_musculus" ]]; then
						species_label="Mm"
					else
						species_label="Hs"
					fi
					combined_gmx="combined_${species_label}_genesets.gmt"
					combined_gmx_path="${run_dir}/${combined_gmx}"
					> "$combined_gmx_path"
					for gene_set in "${gene_sets_dir}"/*.gmt; do
						[[ -f "$gene_set" ]] || continue
						filename=$(basename "$gene_set")
						# handle MSigDB files (always has year version on name, e.g. ...v2026...)
						if [[ "$filename" =~ \.v20[0-9]{2} ]]; then
							# if its mouse and file doesnt start with M skip it
							if [[ "$species_label" == "Mm" && ! "$filename" =~ ^m ]]; then
								continue
							fi
							# if its human and file starts with M skip it
							if [[ "$species_label" == "Hs" && "$filename" =~ ^m ]]; then
								continue
							fi
						fi
						#  everything else passing the criterias is combined
						cat "$gene_set" >> "$combined_gmx_path"
					done
					cp "$combined_gmx_path" "/data/${gsea_dir}"
					parameters["gmx"]="$combined_gmx_path"
				fi
			fi

			# collapse mode and provided chip set file checks
			if [[ -n "$collapse" ]]; then
				if [[ "$collapse" != "Collapse" ]] && [[ "$collapse" != "Remap_only" ]]; then
					# Case: User wants to collapse/remap but forgot the chip file
					if [[ -z "$chip" ]]; then
						printf "❌ [MODULE 6] Configuration Error: 'collapse' method (%s) specified without a 'chip' file (set in the config).\n" "$collapse" >&2
						exit 1
					fi
					# Case: Both collapse and chip are provided
					parameters["collapse"]="$collapse"
					# Resolve and copy the chip file safely
					if [[ -f "/data/$chip" ]]; then
						cp "/data/$chip" "${run_dir}/"
						parameters["chip"]="$(basename "$chip")"
					else
						printf "❌ [MODULE 6] Error: Provided chip file '/data/%s' not found.\n" "$chip" >&2
						exit 1
					fi
				elif [[ "$collapse" == "No_Collapse" ]]; then
					parameters["collapse"]="No_Collapse"
					# No chip needed for No_Collapse
				else
					printf "❌ [MAIN] Configuration Error: Invalid collapse '%s'. Options are: 'Collapse', 'Remap_only' or 'No_collpase'.\n" "$method" >&2
				fi
			fi

			case "$method" in
				classic)
					run_file="/data/${gsea_dir}/gsea_classic_parameters"
					parameters["permute"]="phenotype"
					if [[ "$prep_gsea_inputs_ran" == true ]]; then
						printf "Using prepared inputs (method = '%s')\n" "$method"
						printf "Running GSEA Classic with prepared inputs...\n"
						inputs_dir="/data/${gsea_dir}/classic_inputs"
						cp "${inputs_dir}/expression_dataset.gct" "${run_dir}"
						cp "${inputs_dir}/phenotype_labels.cls" "${run_dir}"
						parameters["res"]="expression_dataset.gct"
						parameters["cls"]="phenotype_labels.cls"
					else
						if [[ -n "$res" && -n "$cls" ]]; then
							cp "${inputs_dir}/${res}" "${run_dir}"
							cp "${inputs_dir}/${cls}" "${run_dir}"
							parameters["res"]="$(basename "${res}")"
							parameters["cls"]="$(basename "${cls}")"
							printf "Running GSEA Classic with provided .gct and .cls files...\n"
						else
							printf "❌ [MAIN] Configuration Error: For 'classic' method, if not running module 5 (prepare gsea inputs), you must configure and provide both 'res' and 'cls' files.\n" >&2
							exit 1
						fi
					fi

					# fill any left over empty parameters set in the config by the user
					for key in "${!parameters[@]}"; do
						if [[ -z "${parameters[$key]}" && -n "${!key}" ]]; then
							parameters["$key"]="${!key}"
						fi
					done

					# if chip not provided then build one
					if [[ -z "$chip" ]]; then
						# chip set file build (pass dataset set in the config [res])
						chip_file="/data/${gsea_dir}/chip_file_classic.chip"
						./6_gsea_plus/generate_chip_file.sh "${parameters["res"]}" "${chip_file}" "${species_map}"
						# if expression expression_dataset.gct already as gene symbols, no chip needed (and no collapse)
						if [[ -f "${chip_file}" ]]; then
							# File exists: Copy it and set parameters to Collapse
							cp "${chip_file}" "${run_dir}/"
							parameters["chip"]="$(basename "${chip_file}")"
							parameters["collapse"]="Collapse"
						else
							# File does not exist: Handle No_Collapse
							parameters["collapse"]="No_Collapse"
							# Optional: Unset the chip key so GSEA doesn't look for a missing file
							unset 'parameters["chip"]' 
						fi
					fi

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
					# gsea run
					./6_gsea_plus/run.sh "$run_file" "${save_dir}"
					if [[ $? -ne 0 ]]; then
						printf "❌ [MAIN - MODULE 6] Critical Error: GSEA Preranked run failed. Check logs for details.\n" >&2
						exit 1
					fi
					;;
				preranked)
					shopt -s nullglob
					parameters["permute"]="gene_set"
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
							cp "${rnk}" "${run_dir}"
							parameters["rnk"]="$(basename "${rnk}")"
							base_name=$(basename "$rnk" .rnk | tr ' ' '_')
							printf "Processing: %s\n" "$base_name"
							run_file="/data/${gsea_dir}/parameters_${base_name}"

							# fill any left over empty parameters set in the config by the user
							for key in "${!parameters[@]}"; do
								if [[ -z "${parameters[$key]}" && -n "${!key}" ]]; then
									parameters["$key"]="${!key}"
								fi
							done

							if [[ -z "$chip" ]]; then
								# chip set file build (pass dataset set in the config [rnk])
								chip_file="/data/${gsea_dir}/chip_set_${base_name}.chip"
								./6_gsea_plus/generate_chip_file.sh "${parameters["rnk"]}" "${chip_file}" "${species_map}"
								# if expression RNK already as gene symbols, no chip needed (and no collapse)
								if [[ -f "${chip_file}" ]]; then
									# File exists: Copy it and set parameters to Collapse
									cp "${chip_file}" "${run_dir}/"
									parameters["chip"]="$(basename "${chip_file}")"
									parameters["collapse"]="Collapse"
								else
									# File does not exist: Handle No_Collapse
									parameters["collapse"]="No_Collapse"
									# Optional: Unset the chip key so GSEA doesn't look for a missing file
									unset 'parameters["chip"]' 
								fi
							fi

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

							# gsea run
							./6_gsea_plus/run.sh "$run_file" "${save_dir}"
							if [[ $? -ne 0 ]]; then
								printf "❌ [MAIN - MODULE 6] Critical Error: GSEA Preranked run failed. Check logs for details.\n" >&2
								exit 1
							fi
						done
					else
						printf "❌ [MAIN] Configuration Error: No preranked (.rnk) files found to process.\n" "${inputs_dir}" >&2
						exit 1
					fi
					;;
				*)
					printf "❌ [MAIN] Configuration Error: Invalid method '%s'. Please specify 'classic' or 'preranked'.\n" "$method" >&2
					exit 1
					;;
			esac
			printf "✅ [MODULE 6] GSEA run completed successfully with significant results.\n"
			;;

		7) # Module 7 (Filter EA results) - mandatory filtering parametes in config()
			printf "🚀 [MODULE 7] Initializing: Filtering Enrichment Analysis Annotations results\n"

			# add new future tols to the associative array
			declare -A TOOLS_DIR=(
				["gprofiler"]="/data/gprofiler"
				["panther"]="/data/panther"
				# ["my_new_tool"]="/data/$new_tool_dir"
			)

			gsea_results="/data/$gsea_dir/results"
			common_results_dir="/data/common_results"

			# create directory if doesnt exist
			[[ ! -d "$common_results_dir" ]] && mkdir -p "$common_results_dir"

			# funciton to run comparison agaisnt GSEA
			run_intersection() {
				local primary_args=("$@")
			
				# no results, no intersect
				[[ ${#primary_args[@]} -eq 0 ]] && return

				# run gprofiler and panther, or gprofiler/panther onyl agaisnt gsea
				if [[ -d "$gsea_results" ]]; then
					for gsea_subdir in "$gsea_results"/*; do
						if [[ -d "$gsea_subdir" && -f "$gsea_subdir/enrichment_fields.tsv" ]]; then
							./7_filter_ea_results/intersect_methods.sh "${primary_args[@]}" "$gsea_subdir"
						fi
					done
				else
					./7_filter_ea_results/intersect_methods.sh "${primary_args[@]}"
				fi
			}

			# intersect the same results of the same input (same results directory name) of panther and gprofiler
			if [[ "$intersection" == true ]]; then

				# find all unique run directories across configured tools (gprofiler and panther)
				declare -A UNIQUE_RUNS
				for tool in "${!TOOLS_DIR[@]}"; do
					base_dir="${TOOLS_DIR[$tool]}"
					echo "$base_dir"
					if [[ -d "$base_dir" ]]; then
						for subdir in "$base_dir"/*; do
							[[ -d "$subdir" ]] && UNIQUE_RUNS["$(basename "$subdir")"]=1
						done
					fi
				done

				printf "Found %d run directories across tools.\n" "${#UNIQUE_RUNS[@]}"

				# loop through every unique run name
				for run in "${!UNIQUE_RUNS[@]}"; do
					# This array will dynamically hold the paths that actually exist for this sample
					intersect_args=()
					# dynamically poll every tool to see if it has data for this specific sample
					for tool in "${!TOOLS_DIR[@]}"; do
						run_path="${TOOLS_DIR[$tool]}/$run"
						if [[ -d "$run_path" && -f "$run_path/enrichment_fields.tsv" ]]; then
							printf "Processing run: %s\n" "$run_path"
							intersect_args+=("$run_path")
						else
							printf "Intersection: no results file 'enrichment_fields.tsv' found in %s" "$run_path"
						fi
					done
					# run intersection of collected runs
					run_intersection "${intersect_args[@]}"
				done
			fi

			# filter_args=""
			# [[ -n "$max_occur" ]] && filter_args+=" --max-occurrence $max_occur"
			# [[ -n "$max_annot" ]] && filter_args+=" --max-annotations $max_annot"
			# [[ -n "$min_ratio" ]] && filter_args+=" --min-ratio $min_ratio"

			# for tool_name in "gProfiler" "PANTHER"; do
			# 	# Select the appropriate base directory
			# 	if [[ "$tool_name" == "gProfiler" ]]; then
			# 		base_dir="/data/$gprof_dir"
			# 	else
			# 		base_dir="/data/$panther_dir"
			# 	fi

			# 	if [[ -d "$base_dir" ]]; then
			# 		printf "\nFiltering %s results...\n" "$tool_name"
			# 		# Loop through every map directory's results folder
			# 		for results_dir in "$base_dir"/*/results; do
			# 			if [[ -d "$results_dir" && -f "$results_dir/enriched_terms_annotations.csv" ]]; then
			# 				# Extract map name and strip '_map' suffix for logging
			# 				map_dir=$(basename "$(dirname "$results_dir")")
			# 				target="${map_dir%_map}"
			# 				./7_filter_ea_results/run.sh "${results_dir}" $filter_args
			# 				if [[ $? -eq 0 ]]; then
			# 					printf "✅ %s results filtered successfully (%s).\n" "$tool_name" "$target"
			# 					any_processed=true
			# 				else
			# 					printf "❌ Error: Filtering %s results failed (%s).\n" "$tool_name" "$target"
			# 					exit 1
			# 				fi
			# 			fi
			# 		done
			# 	fi
			# done

			# # process GSEA (different results directory structure)
			# base_dir="/data/$gsea_dir/results"
			# if [[ -d "$base_dir" ]]; then
			# 	printf "\nFiltering GSEA results...\n"
			# 	# Loop through every subdirectory inside results/
			# 	for subdir in "$base_dir"/*/; do
			# 		if [[ -d "$subdir" && -f "$subdir/enriched_terms_annotations.tsv" ]]; then
			# 			target=$(basename "$subdir")
			# 			results_dir="${subdir%/}"
			# 			# Run the filter script
			# 			./7_filter_ea_results/run.sh "${rel_path}" $filter_args
			# 			if [[ $? -eq 0 ]]; then
			# 				printf "✅ GSEA results filtered successfully (%s).\n" "$target"
			# 				any_processed=true
			# 			else
			# 				printf "❌ Error: Filtering GSEA results failed (%s).\n" "$target"
			# 				exit 1
			# 			fi
			# 		fi
			# 	done
			# fi

			# if [[ "$any_processed" == false ]]; then
			# 	printf "❌ No enrichment analysis results found to filter.\n"
			# 	exit 1
			# fi
			;;
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
