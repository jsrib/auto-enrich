#!/bin/bash
set -e

if [ $# -lt 2 ]; then
	printf "Usage: %s <ids_map_file> <taxon_id> [panther_dbs]\n" "$0"
	exit 1
fi

input_file="$1"
taxon_id="$2"
panther_dbs="${3:-}"

query_ids=$(awk -F'\t' 'NF && $1 != "" { print "GeneID:" $1 }' "$input_file" | paste -sd',' -)

panther_dbs=$(printf '%s' "$panther_dbs" | tr -d '[:space:]')

if [[ -z $panther_dbs ]]; then
	printf "Requesting to all available datasets\n"
	datasets=(
	"GO:0003674"
	"GO:0008150"
	"GO:0005575"
	"ANNOT_TYPE_ID_PANTHER_GO_SLIM_MF"
	"ANNOT_TYPE_ID_PANTHER_GO_SLIM_BP"
	"ANNOT_TYPE_ID_PANTHER_GO_SLIM_CC"
	"ANNOT_TYPE_ID_PANTHER_PC"
	"ANNOT_TYPE_ID_PANTHER_PATHWAY"
	"ANNOT_TYPE_ID_REACTOME_PATHWAY"
	)
else
# datasets select
	printf "Requesting to selected datasets: %s\n" "$panther_dbs"
	IFS=',' read -ra selected_dbs <<< "$panther_dbs"
	datasets=()
	for db_raw in "${selected_dbs[@]}"; do
		db=$(printf '%s' "$db_raw" | tr '[:lower:]' '[:upper:]' | tr -d ' ')
		case "$db" in
			PANTHER_PC|PANTHERPC|PANTHER_PC)  datasets+=("ANNOT_TYPE_ID_PANTHER_PC")  ;;
			REAC|REACTOME|REACTOME_PATHWAY|REACTOMEPATHWAY)  datasets+=("ANNOT_TYPE_ID_REACTOME_PATHWAY")  ;;
			PANTHER_PATH|PANTHERPATH|PANTHER_PATHWAY|PANTHERPATHWAY) datasets+=("ANNOT_TYPE_ID_PANTHER_PATHWAY") ;;
			GO_CC|GO:CC|GOCC) datasets+=("GO:0005575") ;;
			GO_BP|GO:BP|GOBP) datasets+=("GO:0008150") ;;
			GO_MF|GO:MF|GOMF) datasets+=("GO:0003674") ;;
			GO_SLIM_CC|GO:SLIM:CC|PANTHER_GO_CC|PANTHERGOCC|PANTHERGO:CC|PANTHERGOSLIMCC) datasets+=("ANNOT_TYPE_ID_PANTHER_GO_SLIM_CC") ;;
			GO_SLIM_BP|GO:SLIM:BP|PANTHER_GO_BP|PANTHERGOBP|PANTHERGO:BP|PANTHERGOSLIMBP) datasets+=("ANNOT_TYPE_ID_PANTHER_GO_SLIM_BP") ;;
			GO_SLIM_MF|GO:SLIM:MF|PANTHER_GO_MF|PANTHERGOMF|PANTHERGO:MF|PANTHERGOSLIMMF) datasets+=("ANNOT_TYPE_ID_PANTHER_GO_SLIM_MF") ;;
			*) printf "Warning: Unknown dataset code '%s', skipping." "$db_raw" ;;
		esac
	done
fi

if [ ${#datasets[@]} -eq 0 ]; then
	printf "No valid datasets selected. Exiting.\n"
	exit 1
fi

# make request to each dataset
for dataset in "${datasets[@]}"; do
	output_file="output_${dataset//[^a-zA-Z0-9]/_}.json"

	printf "Requesting enrichment for %s...\n" "$dataset"

	curl -s -X POST "https://www.pantherdb.org/services/oai/pantherdb/enrich/overrep" \
		-H "accept: application/json" \
		-H "Content-Type: application/x-www-form-urlencoded" \
		--data-urlencode "geneInputList=${query_ids}" \
		--data-urlencode "organism=${taxon_id}" \
		--data-urlencode "annotDataSet=${dataset}" \
		--data-urlencode "enrichmentTestType=FISHER" \
		--data-urlencode "correction=FDR" \
		-o "$output_file"

	printf "Output saved to %s.\n\n" "$output_file"
done
