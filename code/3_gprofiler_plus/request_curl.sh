#!/bin/bash

if [ $# -lt 2 ]; then
	printf "Usage: %s <ids_map_file> <species> [gprofiler_dbs]\n" "$0"
	exit 1
fi

input_file="$1"
species="$2"
gprofiler_dbs="${3:-}"

query_ids=$(awk -F'\t' 'NF && $1 != "" { print $1 }' "$input_file")

gprofiler_dbs=$(printf '%s' "$gprofiler_dbs" | tr -d '[:space:]')

if [[ -z $gprofiler_dbs ]]; then
	printf "Requesting to all available datasets\n"
	datasets=("GO:MF" "GO:CC" "GO:BP" "KEGG" "REAC" "WP" "TF" "MIRNA" "HPA" "CORUM" "HP")
else
	printf "Requesting to selected datasets: %s\n" "$gprofiler_dbs"
	IFS=',' read -ra selected_dbs <<< "$gprofiler_dbs"
	datasets=()
	for db_raw in "${selected_dbs[@]}"; do
		db=$(printf '%s' "$db_raw" | tr '[:lower:]' '[:upper:]' | tr -d ' ')	# normalize
		case "$db" in
			GO_CC|GO:CC|GOCC) datasets+=("GO:CC") ;;
			GO_BP|GO:BP|GOBP) datasets+=("GO:BP") ;;
			GO_MF|GO:MF|GOMF) datasets+=("GO:MF") ;;
			KEGG|KEGGPATHWAYS|KEGGPATHWAY|KEGG_PATHWAY|KEGG_PATHWAYS) datasets+=("KEGG")  ;;
			REAC|REACTOME|REACTOME_PATHWAY|REACTOMEPATHWAY) datasets+=("REAC")  ;;
			WP|WIKIPATHWAYS|WIKIPATHWAY|WIKI_PATHWAY|WIKI_PATHWAYS) datasets+=("WP")  ;;
			TF|TRANSFAC) datasets+=("TF") ;;
			MIRNA|MIRTARBASE) datasets+=("MIRNA") ;;
			HPA|HUMANPROTEINATLAS|HUMAN_PROTEIN_ATLAS) datasets+=("HPA") ;;
			CORUM) datasets+=("CORUM") ;;
			HP|HUMANPHENOTYPEONTOLOGY|HUMAN_PHENOTYPE_ONTOLOGY) datasets+=("HP") ;;
			*) printf "Warning: Unknown dataset code '%s', skipping." "$db_raw" ;;
		esac
	done
fi

if [ ${#datasets[@]} -eq 0 ]; then
	printf "No valid datasets selected. Exiting.\n"
	exit 1
fi

# convert to json
datasets_json=$(printf '"%s",' "${datasets[@]}" | sed 's/,$//')
query_array=$(printf "%s\n" "$query_ids" | awk '{printf "\"%s\",", $0}' | sed 's/,$//')
json_data="{\"organism\": \"$species\", \"query\":[$query_array], \"sources\":[$datasets_json], \"significance_threshold_method\": \"fdr\", \"user_threshold\": \"0.05\"}"

curl -s -X POST -H "Content-Type: application/json" \
	-d "$json_data" \
	'https://biit.cs.ut.ee/gprofiler/api/gost/profile/' > raw_output
