#!/bin/bash
<<<<<<< HEAD
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

# paths (in /data)
annotations_dir="annotations"
=======
#set -eo pipefail

if [ ! -f "/data/config0" ]; then
	printf "❌ Error: config0 not found.\n"
	exit 1
else
	sed -i 's/\r$//' /data/config0
	source /data/config0
fi

# tool numbers:
# 1 = prepare_lists (needs config 1)
# 2 = id_mapping_info
# 3 = gprofiler
# 4 = panther
# 5 = prep_gsea_inputs (needs config 5)
# 6 = gsea (needs gsea_parameters)
# 7 = filter_ea_results (need variables in config0)
# 8 = build_plots (needs variables in config0)

# tools flags
annotations_directory=false
prepare_lists_ran=false
prep_gsea_inputs_ran=false

# paths
annotations_dir="/data/annotations"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
prepared_lists_dir="prepared_gene_lists"
maps_dir="mapped_gene_lists"
gprof_dir="gprofiler"
panther_dir="panther"
gsea_dir="gsea"

<<<<<<< HEAD
# modules run flags
prepare_lists_ran=false
prep_gsea_inputs_ran=false

if [[ -d "/data/$annotations_dir" ]]; then
	printf "[MAIN] Using provided annotations files inside annotations directory...\n"
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
		IFS=$'\t' read -r display_name gprof_curl_id scientific_name_ori taxon <<< "$result"
		printf "[MAIN] Match Found!\n"
		printf "   --------------------------------------\n"
		printf "   Common Name: %s\n" "${display_name}"
		printf "   gProf curl ID: %s\n" "${gprof_curl_id}"
		printf "   Scientific Name: %s\n" "${scientific_name_ori}"
		printf "   Taxon ID: %s\n" "${taxon}"
		printf "   --------------------------------------\n"
	fi
fi

# species ids map file (required in various modules, best to always have it)
scientific_name=$(echo "$scientific_name_ori" | tr ' ' '_')	# tr '[:upper:]' '[:lower:]'
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
				printf "⚠️  [MODULE 1] No genes left after set calculations and thresholds.\n"
			else
				printf "❌ [MAIN - MODULE 1] Critical Error: Failed to process expression matrix. Check logs for details.\n" >&2
=======
# species provided for tools 2,3 or 4?
if [[ "$tools" =~ (^|,)2($|,) || "$tools" =~ (^|,)3($|,) || "$tools" =~ (^|,)4($|,) ]]; then
	if [[ -z "$species" ]]; then
		printf "❌ Error: Species must be defined when using tools 2, 3, or 4.\n"
		exit 1
	fi

	if [[ -d "$annotations_dir" ]]; then
		printf "\nAnnotations directory found, using provided annotations files inside.\n"
		annotations_directory=true
	else
		printf "\nAnnotations directory NOT found, creating new directory and annotations files.\n"
		mkdir -p "$annotations_dir"
	fi
fi

# normalize species name to short form
species=$(echo "$species" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z_]*//g')
if [[ "$species" == *"_"* ]]; then
	species_short="${species:0:1}${species#*_}"
else
	species_short="$species"
fi

IFS=',' read -ra selected_tools <<< "$tools"
for tool in "${selected_tools[@]}"; do
	case "$tool" in
		1)	# Module 1 prepare_lists - config1 file mandatory ()
			printf "Running tool 1 (prepare_lists): Pre-processing step to prepare gene lists.\n"
			if [[ -f "/data/config1" ]]; then
				./1_prepare_lists/run.sh "/data/config1"
				if [ $? -eq 0 ]; then
					printf "✅ Prepare lists run completed successfully.\n"
					prepare_lists_ran=true
				else
					printf "❌ Error: Prepare lists run failed.\n"
					exit 1
				fi
			else
				printf "❌ Error: config1 file not found in assigned /data."
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
				exit 1
			fi
			;;

		2)	# Module 2 (map_ids_info) - /prepared_gene_lists directory must be present()
<<<<<<< HEAD
			printf "\n🚀 [MODULE 2] Initializing: Mapping genes information (GeneID, Uniprot and Symbol)...\n"
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
				
				if [[ ! -f "$output" ]]; then
					./2_gene_mapping/run.sh "${glist}" "${species_map}" "${taxon}"  "${output}"
					status=$?
				else
					printf "⚠️  [MODULE 2] Warning: Mapped list file '%s' already exists. Skipping...\n" "$output"
					continue
				fi

				if [[ $status -ne 0 ]]; then
					printf "❌ [MAIN - MODULE 2] Critical Error: Failed to map GeneIDs lists. Check logs for details.\n" >&2
					exit 1	
				else
					printf "✅ [MODULE 2] Success: Gene list '%s' mapped ! Saved in %s.\n" "$basename" "$output"
				fi
			done
			printf "[MODULE 2] Mapping complete. Check '%s' directory!\n" "$maps_dir"
			;;

		3) # Module 3 (gProfiler plus) - mapped_gene_lists directory in /data, species and gprofiler dbs variables in config()
			printf "\n🚀 [MODULE 3] Initializing: Running Enrichment Analysis with g:Profiler g:GOSt tool...\n"
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
						cp $input_map $save_dir
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
			printf "[MODULE 3] Complete: gProfiler analysis finished. Check 'gprofiler/results' for results!\n"
			;;

		4) # Module 4 (PANTHER plus) - species and gprofiler dbs variables in config0()
			printf "\n🚀 [MODULE 4] Initializing: Running PANTHER enrichment analysis...\n"
			panther_gene_sets="/data/$annotations_dir/${scientific_name}_PTHR19.0_gene_sets.gmt"
			reactome_gene_sets="/data/$annotations_dir/${scientific_name}_REAC_pathways.gmt"
			gos_gene_sets="/data/$annotations_dir/${scientific_name}_GO_terms.gmt"

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
						cp $input_map ../$save_dir
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
			printf "[MODULE 4] Complete: PANTHER analysis finished. Check 'panther/results' for results!\n"
			;;

		5) # Module 5 (Prep GSEA inputs) - mandatory config5 ()
			printf "\n🚀 [MODULE 5] Initializing: Preparing GSEA inputs\n"
			save_dir="/data/${gsea_dir}"
			./5_prep_gsea_inputs/run.sh "$config" "$save_dir"
			if [[ $? -ne 0 ]]; then
				printf "❌ [MAIN - MODULE 5] Critical Error: GSEA input preparation failed. Check logs for details.\n" >&2
=======
			printf "\nRunning tool 2 (ids-mapping): Mapping gene IDs.\n"
			mkdir -p "/data/$maps_dir"
			maps=()

			# handle map file load and unload from /annotations do /data
			handle_ids_map_file() {
				local action=$1  # "load" or "unload"
				local suffix=$2
				local file_name="${species_short}_${suffix}"
				local source_file="${annotations_dir}/${file_name}"
				local working_file="/data/${file_name}"

				if [[ "$action" == "load" ]]; then
					if [[ -f "$source_file" ]]; then
						printf "Using IDs map file: %s\n" "$file_name"
						mv "$source_file" "$working_file"
					fi
				elif [[ "$action" == "unload" ]]; then
					if [[ -f "$working_file" ]]; then
						mv "$working_file" "$annotations_dir/"
					fi
				fi
			}

			# ensure unload even if script exits early
			cleanup_ids_mapping() {
				for suffix in "ids_map"; do
					handle_ids_map_file unload "$suffix"
				done
			}
			trap cleanup_ids_mapping EXIT

			# detect gene lists to map
			map_gene_lists() {
				if [[ "$prepare_lists_ran" == true ]]; then
					gene_lists=("/data/$prepared_lists_dir"/*_genes_*)
				else
					gene_lists=("/data/$prepared_lists_dir"/*)
				fi

				if [[ ${#gene_lists[@]} -eq 0 ]]; then
					printf "❌ No genes lists files found in %s.\n" "$prepared_lists_dir"
					exit 1
				fi

				printf "Multiple gene condition lists found in %s:\n" "$prepared_lists_dir"
					for plist in "${gene_lists[@]}"; do
						run_ids_mapping "$plist"
					done
			}

			run_ids_mapping() {
				local input_path=$1
				local ids_path="${input_path#/data/}"
				local base_name
				base_name=$(basename "$input_path")
				local map_name="${base_name%.*}_map"	# strip exts for name

				printf "Mapping %s to %s...\n" "$base_name" "$map_name"
				sed -i 's/\r$//' "${ids_path}"
				./2_mapping_info/run.sh "$ids_path" "$species_short" "$map_name"
				if [ $? -eq 0 ]; then
					printf "✅ IDs_mapping_info run completed successfully.\n"
					mv "/data/$map_name" "/data/$maps_dir"
					maps+=("/data/$maps_dir/$map_name")
				else
					printf "❌ Error: IDs_mapping_info run failed for input: %s\n" "$input_path" >&2
					exit 1
				fi
			}

			if [[ "$annotations_directory" == true ]]; then
				for suffix in "ids_map"; do
					handle_ids_map_file load "$suffix"
				done
			fi

			if [[ "$prepare_lists_ran" == true ]]; then
				printf "Detected output from Tool 1. Mapping all generated gene lists.\n"
				map_gene_lists

			elif [[ -d "/data/$prepared_lists_dir" ]]; then
				map_gene_lists

			else
				printf "❌ Error: No expression data, gene list, or prepared gene lists found.\n"
				exit 1
			fi
			
			for suffix in "ids_map"; do
				handle_ids_map_file unload "$suffix"
			done
			;;

		
		3) # Module 3 (gProfiler plus) - species and gprofiler dbs variables in config0()
			printf "\nRunning Tool 3 (gProfiler_Plus) - Running Enrichment Analysis with g:Profiler g:GOSt tool\n"
			gprof_annot_file="${species_short}_gProfiler_annotations.gmt"
			working_annot_file="/data/$gprof_annot_file"
			final_annot_path="$annotations_dir/$gprof_annot_file"

			# move annotation file to /data before runs
			if [[ "$annotations_directory" == true ]]; then
				annot_file=$(find "$annotations_dir" -type f -name "$gprof_annot_file")
				if [[ -n "$annot_file" && -f "$annot_file" ]]; then
					printf "gProfiler annotations file for %s found: %s.\n" "$species" "$annot_file"
					mv "$annot_file" "$working_annot_file"
				fi
			fi

			cleanup_gprof_annotation() {
				if [[ -f "$working_annot_file" ]]; then
					mv "$working_annot_file" "$final_annot_path"
				fi
			}
			trap cleanup_gprof_annotation EXIT

			run_gprofiler() {
				local input_file=$1
				local base_name
				local dbs=$2
				base_name=$(basename "$input_file")
				local save_name="${base_name%_map}"
				local save_dir="/data/${gprof_dir}/${save_name}"

				printf "\nRunning gProfiler for: %s\n" "$base_name"
				./3_gprofiler_plus/run.sh "$maps_dir/$base_name" "$species_short" "$dbs"

				local status=$?

				if [ $status -eq 2 ]; then	#nNo significant results found
					printf "⚠️ gProfiler run completed with no significant results (exit code 2).\n"
				elif [ $status -eq 1 ]; then	# actual error
					printf "❌ Error: gProfiler run failed (exit code 1). Check logs.\n"
					exit 1
				else
					printf "✅ gProfiler run completed successfully.\n"
					mkdir -p "$save_dir"
					mv /data/results "$save_dir"
					cp "$input_file" "$save_dir/"
					printf "Saved results in: %s\n" "$save_dir/results"
				fi
			}

			# input prepared gene lists by module 1
			if [[ "$prepare_lists_ran" == true ]]; then
				printf "Running g:Profiler g:GOSt on all prepared gene lists...\n"
				for gene_map in "${maps[@]}"; do
					run_gprofiler "$gene_map" "$gprofiler_dbs"
				done
			# input pre-generated mapped gene lists
			else
				map_files=(/data/"$maps_dir"/*_map)
				if [[ -d "/data/$maps_dir" && ${#map_files[@]} -gt 0 ]]; then
					printf "Running gProfiler g:GOSt on mapped files in %s...\n" "/data/$maps_dir"
					for map_file in "${map_files[@]}"; do
						run_gprofiler "$map_file" "$gprofiler_dbs"
					done
				else
					printf "❌ No mapped_gene_lists directory found or no *_map files present, and no input provided.\n"
					exit 1
				fi
			fi
			;;

		4) # Module 4 (PANTHER plus) - species and gprofiler dbs variables in config0()
			printf "\nRunning Tool 4 (PANTHER plus) - Running enrichment analysis using PANTHER Over-Representation test\n"
			# load and unload annotations files
			handle_annotation_file() {
				local action=$1  # "load" or "unload"
				local suffix=$2
				local file_name="${species_short}_${suffix}"
				local source_file="${annotations_dir}/${file_name}"
				local working_file="/data/${file_name}"

				if [[ "$action" == "load" ]]; then
					if [[ -f "$source_file" ]]; then
						printf "Using annotation: %s\n" "$file_name"
						mv "$source_file" "$working_file"
					fi
				elif [[ "$action" == "unload" ]]; then
					if [[ -f "$working_file" ]]; then
						mv "$working_file" "$annotations_dir/"
					fi
				fi
			}

			run_panther() {
				local input_file=$1
				local base_name=$(basename "$input_file")
				local save_name="${base_name%_map}"
				local save_dir="/data/${panther_dir}/${save_name}"
				local dbs=$2
				
				if [[ "$annotations_directory" == true ]]; then
					for suffix in "PTHR19.0_annotations" "REAC_annotations" "gene_uniprot"; do
						handle_annotation_file load "$suffix"
					done
				fi
				
				printf "\nRunning PANTHER for: %s\n" "$base_name"
				./4_panther_plus/run.sh "$maps_dir/$base_name" "$species_short" "$dbs"

				local status=$?

				if [[ "$annotations_directory" == true ]]; then
					for suffix in "PTHR19.0_annotations" "REAC_annotations" "gene_uniprot"; do
						handle_annotation_file unload "$suffix"
					done
				fi

				if [ $status -eq 2 ]; then	# no results found
					printf "⚠️  PANTHER run completed with no significant results (exit code 2).\n"
				elif [ $status -eq 1 ]; then	# actual error
					printf "❌ Error: PANTHER run failed (exit code 1). Check logs.\n"
					exit 1
				else
					printf "✅ PANTHER run completed successfully (exit code $status).\n"
					mkdir -p "$save_dir"
					mv /data/results "$save_dir"
					cp "$input_file" "$save_dir/"
					printf "Saved results in: %s\n" "$save_dir/results"
				fi
			}

			# input prepared gene lists by module 1
			if [[ "$prepare_lists_ran" == true ]]; then
				printf "Running PANTHER analysis on all prepared gene lists...\n"
				for gene_map in "${maps[@]}"; do
					run_panther "$gene_map" "$panther_dbs"
				done
			# input pre-generated mapped gene lists
			else
				map_files=(/data/"$maps_dir"/*_map)
				if [[ -d "/data/$maps_dir" && ${#map_files[@]} -gt 0 ]]; then
					printf "Running PANTHER analysis on mapped files in %s...\n" "/data/$maps_dir"
					for map_file in "${map_files[@]}"; do
						run_panther "$map_file" "$panther_dbs"
					done
				else
					printf "❌ No mapped_gene_lists directory found or no *_map files present, and no input provided.\n"
					exit 1
				fi
			fi
			;;

		5) # Module 5 (Prep GSEA inputs) - mandatory config5 ()
			printf "\nRunning tool 5 (Preparing GSEA inputs)\n"
			config_file="/data/config5"
			if [[ ! -f "$config_file" ]]; then
				printf "❌ Error: config5 file not found in assigned /data. Exiting...\n"
				exit 1
			else
				sed -i 's/\r$//' "$config_file"
				source "$config_file"
			fi

			mkdir -p "/data/${gsea_dir}/inputs"
			./5_prep_gsea_inputs/run.sh "$config_file"
			if [[ $? -ne 0 ]]; then
				printf "❌ Error: Prepare GSEA inputs failed.\n"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
				exit 1
			fi

			prep_gsea_inputs_ran=true
<<<<<<< HEAD
			printf "✅ [MODULE 5] GSEA inputs prepared successfully. Saved under %s\n" "$save_dir"
			;;

		6) # GSEA plus - mandatory gsea_parameters file()
			printf "\n🚀 [MODULE 6] Initializing: Running Gene Set Enrichment Analysis (GSEA)...\n"
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
				[plot_top_x]=10			# number of top gene sets to plot in results (this also generates the 'core enrichment' genes <=> "genes_in_intersection"). pipeline default: 1000; gsea default: 20
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
					parameters["gmx"]="$combined_gmx"
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
					# both collapse and chip are provided
					parameters["collapse"]="$collapse"
					# resolve and copy the chip file safely
					if [[ -f "/data/$chip" ]]; then
						cp "/data/$chip" "${run_dir}/"
						parameters["chip"]="$(basename "$chip")"
					else
						printf "❌ [MODULE 6] Error: Provided chip file '/data/%s' not found.\n" "$chip" >&2
						exit 1
					fi
				elif [[ "$collapse" == "No_Collapse" ]]; then
					parameters["collapse"]="No_Collapse"
					# no chip needed for No_Collapse
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
							# file create. Option: Collapse
							cp "${chip_file}" "${run_dir}/"
							parameters["chip"]="$(basename "${chip_file}")"
							parameters["collapse"]="Collapse"
						else
							# file not create (input already has gene symbols). Option: No_Collapse
							parameters["collapse"]="No_Collapse"
							# unset the chip key so GSEA doesn't look for it
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
			printf "[MODULE 6] GSEA run completed successfully with significant results.\n"
			;;

		7) # Module 7 (Filter EA results) - mandatory filtering parametes in config()
			printf "\n🚀 [MODULE 7] Initializing: Filtering Enrichment Analysis Annotations results\n"

			# add new future tols to the associative array
			declare -A TOOLS_DIR=(
				["gprofiler"]="/data/gprofiler"
				["panther"]="/data/panther"
				# ["my_new_tool"]="/data/$new_tool_dir"
			)

			gsea_results="/data/$gsea_dir/results"
			common_results_dir="/data/common_results"

			[[ ! -d "$common_results_dir" ]] && mkdir -p "$common_results_dir"

			# funciton to run comparison agaisnt GSEA (agaisnt every available result)
			run_intersection() {
				local run_name="$1"
				local primary_args=("$@")
				# no results, no intersect
				[[ ${#primary_args[@]} -eq 0 ]] && return

				local save_dir=""

				# run gprofiler and panther, or gprofiler/panther onyl agaisnt gsea
				if [[ -d "$gsea_results" ]]; then
					for gsea_subdir in "$gsea_results"/*; do
						if [[ -d "$gsea_subdir" && -f "$gsea_subdir/enrichment_fields.tsv" ]]; then
							# save dir name
							local gsea_name=$(basename "$gsea_subdir")
							local gsea_file="${gsea_name%%.*}"
							local gsea_runtype="${gsea_name##*.}"
							save_dir="$common_results_dir/${run_name}_&&_${gsea_file}.${gsea_runtype}"

							[[ ! -d "$save_dir" ]] && mkdir -p "$save_dir"
							# run and copy to dir
							./7_filter_ea_results/intersect_methods.sh "${primary_args[@]}" "$gsea_subdir"
							cd ./7_filter_ea_results && mv common_*_genes.txt report "$save_dir" && cd ..
						fi
					done
				# only compare gprofiler and panther
				else
					save_dir="$common_results_dir/${run_name}_ONLY"
					[[ ! -d "$save_dir" ]] && mkdir -p "$save_dir"
					./7_filter_ea_results/intersect_methods.sh "${primary_args[@]}"
					cd ./7_filter_ea_results && mv common_*_genes.txt report "$save_dir" && cd ..
				fi
			}

			# intersect the same results of the same input (same results directory name) of panther and gprofiler
			if [[ "$intersection" == true ]]; then
				# find all unique run directories across possible tools (gprofiler and panther)
				declare -A DETECTED_RUNS
				for tool in "${!TOOLS_DIR[@]}"; do
					base_dir="${TOOLS_DIR[$tool]}"
					if [[ -d "$base_dir" ]]; then
						for subdir in "$base_dir"/*; do
							[[ -d "$subdir" ]] && DETECTED_RUNS["$(basename "$subdir")"]=1
						done
					fi
				done

				printf "Found %d run directories across tools.\n" "${#DETECTED_RUNS[@]}"
				# loop every run
				for run in "${!DETECTED_RUNS[@]}"; do
					# dynamically hold the paths that actually exist for this sample
					paths_to_intersect=()
					# dynamically poll every tool to see if it has data for this specific sample
					for tool in "${!TOOLS_DIR[@]}"; do
						run_path="${TOOLS_DIR[$tool]}/$run"
						if [[ -d "$run_path" && -f "$run_path/enrichment_fields.tsv" ]]; then
							printf "Processing run: %s\n" "$run_path"
							paths_to_intersect+=("$run_path")
						fi
					done
					# run intersection of collected runs
					if (( ${#paths_to_intersect[@]} > 0 )); then
						run_intersection "$run" "${paths_to_intersect[@]}"
					fi
				done
			fi

			filter_args=""
			[[ -n "$max_occur" ]] && filter_args+=" --max-occurrence $max_occur"
			[[ -n "$max_annot" ]] && filter_args+=" --max-annotations $max_annot"
			[[ -n "$min_coverage" ]] && filter_args+=" --min-coverage $min_coverage"

			if (( ${#filter_args[@]} == 0 )); then
				printf "Filter arguments is empty, no enrichment analysis filtering done...\n"
				exit 1
			fi

			for tool_name in "gProfiler" "PANTHER"; do
				if [[ "$tool_name" == "gProfiler" ]]; then
					base_dir="/data/$gprof_dir"
				else
					base_dir="/data/$panther_dir"
				fi

				if [[ -d "$base_dir" ]]; then
					printf "\nFiltering %s results...\n" "$tool_name"
					# loop every map directory's results folder
					for results_dir in "$base_dir"/*; do
						if [[ -d "$results_dir" && -n $(find "$results_dir" -maxdepth 1 -name "enriched_terms_annotations*.tsv" -print -quit) ]]; then
							# Extract map name and strip '_map' suffix for logging
							map_dir=$(basename "$(dirname "$results_dir")")
							target="${map_dir%_map}"
							./7_filter_ea_results/run.sh "${results_dir}" $filter_args
							status=$?

							case $status in
								0)
									printf "✅ %s results filtered successfully (%s).\n" "$tool_name" "$target"
									;;
								2)
									printf "⚠️ No enrichment results left after filtering.\n" "$tool_name" "$target"
									;;
								*)
									printf "❌ [MAIN - MODULE 7] Error: Filtering %s results failed (%s).\n" "$tool_name" "$target"
									exit 1
									;;
							esac
						fi
					done
				fi
			done

			# process GSEA (different results directory structure)
			base_dir="/data/$gsea_dir/results"
			if [[ -d "$base_dir" ]]; then
				printf "\nFiltering GSEA results...\n"
				# Loop through every subdirectory inside results/
				for subdir in "$base_dir"/*/; do
					if [[ -d "$subdir" && -n $(find "$subdir" -maxdepth 1 -name "enriched_terms_annotations*.tsv" -print -quit) ]]; then
						target=$(basename "$subdir")
						./7_filter_ea_results/run.sh "${results_dir}" $filter_args
						status=$?

						case $status in
							0)
								printf "✅ GSEA results filtered successfully (%s).\n" "$target"
								;;
							2)
								printf "⚠️ No enrichment results left after filtering.\n" "$target"
								;;
							*)
								printf "❌ [MAIN - MODULE 7] Error: Filtering GSEA results failed (%s).\n" "$target"
								exit 1
								;;
						esac
					fi
				done
			fi

			printf "[MODULE 7] Filtering enrichment results completed.\n"
			;;
=======
			printf "✅ GSEA inputs prepared successfully. Saved under /gsea/inputs\n"
			;;

		6) # GSEA plus - mandatory gsea_parameters file()
			printf "\nRunning tool 6 (GSEA plus)\n"
			gsea_parameters="/data/gsea_parameters"
			if [[ ! -f "$gsea_parameters" ]]; then
				printf "❌ Error: gsea_parameters file not found in assigned /data. Exiting...\n"
				exit 1
			fi

			# optional chip file
			collapse=$(awk -F'\t' '$1 == "collapse" { print $2 }' "$gsea_parameters")
			chip=$(awk -F'\t' '$1 == "chip" { print $2 }' "$gsea_parameters")
			if [[ "$collapse" == "Collapse" || "$collapse" == "Remap_Only" ]]; then
				if [[ -n "$chip" && -f "/data/$chip" ]]; then
					cp "/data/$chip" "/data/${gsea_dir}/"
				else
					printf "❌ Error: collapse '%s' requires chip file. File not found.\n" "$collapse"
					exit 1
				fi
			fi

			if [[ "$prep_gsea_inputs_ran" == true ]]; then
				printf "Using prepared inputs (method = %s)\n" "$method"
				gmx_path=$(awk '$1 == "gmx" {print $2}' "$gsea_parameters")
				if [[ -z "$gmx_path" || ! -f "/data/$gmx_path" ]]; then
					printf "❌ GMX file missing or invalid in parameter file.\n"
					exit 1
				fi
				cp "/data/$gmx_path" "/data/${gsea_dir}/inputs"
				
				save_dir="/data/$gsea_dir/results"
				if [[ ! -d "$save_dir" ]]; then
					mkdir -p "$save_dir"
				fi

				case "$method" in
					classic)
						printf "Running GSEA Classic with prepared inputs...\n"

						param_file="/data/${gsea_dir}/inputs/gsea_parameters_classic"
						cp "$gsea_parameters" "$param_file"
						[[ $(tail -c1 "$param_file") != "" ]] && printf "\n" >> "$param_file"	#ensure newline to avoid GSEA errros
						printf "res\texpression_dataset.gct\n" >> "$param_file"
						printf "cls\tphenotype_labels.cls\n" >> "$param_file"
						printf "out\tresults\n" >> "$param_file"

						./6_gsea_plus/run.sh "$param_file"
						if [[ $? -ne 0 ]]; then
							printf "❌ Classic GSEA failed for %s\n" "$base_rnk"
							exit 1
						else
							printf "✅ Classic GSEA run completed successfully with significant results.\n"
							mv /data/results/* "$save_dir"
							printf "Saved results in: %s\n" "$save_dir"
							rm -r /data/results
						fi
						;;

					preranked)
						printf "➡️ Running GSEAPreranked for all .rnk files in preranked_lists...\n"
						rnk_dir="/data/${gsea_dir}/inputs/preranked_lists"
						out_dir="/data/${gsea_dir}/inputs"
						shopt -s nullglob
						# multiple GSEA preranked runs with rnk files
						for rnk_file in "$rnk_dir"/*.rnk; do
							base_rnk=$(basename "$rnk_file")
							temp_rnk_path="${out_dir}/${base_rnk}"
							cp "$rnk_file" "$temp_rnk_path"
							# run time param file
							param_file="${out_dir}/gsea_parameters_${base_rnk%.rnk}"
							cp "$gsea_parameters" "$param_file"
							[[ $(tail -c1 "$param_file") != "" ]] && printf "\n" >> "$param_file"	#ensure newline to avoid GSEA errros
							printf "rnk\t%s\n" "$base_rnk" >> "$param_file"
							printf "out\tresults\n" >> "$param_file"

							./6_gsea_plus/run.sh "$param_file"
							if [[ $? -ne 0 ]]; then
								printf "❌ GSEAPreranked failed for %s\n" "$base_rnk"
								exit 1
							else
								printf "✅ GSEAPreranked run completed successfully with significant results.\n"
								mv /data/results/* "$save_dir"
								printf "Saved results in: %s\n" "$save_dir"
								rm -r /data/results
							fi
							rm -f "$temp_rnk_path"
						done

						shopt -u nullglob
						;;

					*)
						printf "❌ Error: Unknown method value: '%s'. Expected 'classic' or 'preranked'.\n" "$method"
						exit 1
						;;
				esac
			else
				printf "➡️ Running GSEA using manually provided gsea_parameters file...\n"
				if [[ ! -f "$gsea_parameters" ]]; then
					printf "❌ Error: gsea_parameters file not found.\n"
					exit 1
				else
					mkdir /data/"$gsea_dir"
					cp "$gsea_parameters" "/data/${gsea_dir}/"
				fi
				param_file="/data/${gsea_dir}/$(basename "$gsea_parameters")"
				for key in res cls rnk gmx; do
					val=$(awk -F'\t' -v k="$key" '$1 == k { print $2 }' "$param_file")
					if [[ -n "$val" && -f "/data/$val" ]]; then
						cp "/data/$val" "/data/${gsea_dir}/"
					else
						printf "Error: No %s file found in /data to run GSEA\n" "$val"
					fi
				done

				./6_gsea_plus/run.sh "$param_file"
				if [[ $? -ne 0 ]]; then
					printf "❌ GSEA run failed.\n"
					exit 1
				else
					printf "✅ GSEA Plus completed.\n"
					results_dir=$(awk -F'\t' '$1 == "out" { print $2 }' "$param_file")
					save_dir="/data/$gsea_dir/$results_dir"
					if [[ ! -d "$save_dir" ]]; then
						mkdir -p "$save_dir"
					fi
					# organize results
					if [[ -n "$results_dir" && -d "/data/$results_dir" ]]; then
						mv /data/"$results_dir"/* "$save_dir"
						printf "Moved results directory '%s' into GSEA directory.\n" "$results_dir"
						rm -r /data/"$results_dir"
					else
						printf "Warning: results directory not found or not specified.\n"
					fi
				fi
			fi
			;;

		7) # Module 7 (Filter EA results) - mandatory filtering parametes in config0()
			printf "\nRunning tool 7 (Filtering Enrichment Analysis Annotations results)\n"

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

		8) # Module 8 (build plots) - necessary variables on config0 file()
			printf "\nRunning tool 8 (Build Plots) - Building enriched terms counts plots and presence matrices\n"
			config="/data/config0"
			./8_build_plots/run.sh "$config"
			target="/plots_and_gene_matrices/$method"
			if [[ $? -eq 0 ]]; then
				printf "✅ Plots and gene matrices built successfully (%s).\n" "$target"
			else
				printf "❌ Error: Plotting results failed (%s).\n" "$target"
				exit 1
			fi
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
	esac
done

# ---- Additional flags -----
<<<<<<< HEAD
# build reactome hierarchy files (just for REAC dataset)
# not available for GSEA (since it doesnt provide REACTOME Identifiers)
if [[ "$reac_hierarchy" == "true" ]]; then
	for method in gprofiler panther; do
		method_dir="/data/$method"
		if [[ -d "$method_dir" ]]; then
			printf "\n[FLAG] Generating REACTOME hierarchy trees for %s.\n" "$method"
			./flags/reactome_tree/run.sh "$method_dir" "$scientific_name_ori"
=======
# gene_occurences file, only if flag set to y, else dont create file
gene_occurrences="${gene_occurrences,,}"
if [[ "$gene_occurrences" == "y" ]]; then
	for method in gprofiler panther gsea; do
		method_dir="/data/$method"
		if [[ -d "$method_dir" ]]; then
			printf "Generating gene occurences files for %s.\n" "$method"
			./flags/gene_occurrences.sh "$method_dir"
		fi
	done
	printf "Finished\n"
else
	# common misspellings
	case "$gene_occurrences" in
		"gene_occurences"|"gene_ocurences"|"gene_ocurrences")
			printf "Warning: Did you mean 'gene_occurrences'? Flag ignored.\n"
			;;
	esac
fi

# build reactome hierarchy files (just for REAC dataset)
if [[ "$reac_hierarchy" == "y" ]]; then
	for method in gprofiler panther; do
		method_dir="/data/$method"
		if [[ -d "$method_dir" ]]; then
			printf "Generating REACTOME hierarchy trees for %s.\n" "$method"
			source ./4_panther_plus/normalize_name.sh "$species"
			if [[ -z "$long_name" ]]; then
				printf "Input species '%s' not found.\n" "$species"
				exit 1
			fi
			./flags/reactome_tree/run.sh "$method_dir" "$long_name"
>>>>>>> d10f8574b159040860fdef044c1d57a4b6832ffb
		fi
	done
	printf "Finished\n"
fi
