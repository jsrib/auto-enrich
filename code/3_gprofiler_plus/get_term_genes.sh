#!/bin/bash
# set -euo pipefail

if [ $# -ne 4 ]; then
	printf "Usage: %s <input_ids_map_file> <gprof_gene_sets> <results_file> <output_file>\n" "$0"
	exit 1
fi

map_file="$1" # input file with gene id mapping (geneid, uniprot, symbol)
gmt_file="$2"
enriched_fields_file="$3"
save_dir="$4"

output_file="enriched_terms_annotations.tsv"

if [ ! -f "$gmt_file" ]; then
	printf "❌ [MODULE 3] Error: gProfiler gene sets file not found.\n"
	exit 1
fi

if [ ! -f "$enriched_fields_file" ]; then
	printf "❌ [MODULE 3] Error: Enriched fields file '%s' not found.\n" "$enriched_fields_file"
	exit 1
fi

printf "Processing enriched terms annotations...\n"

printf "TermID\tName\tSource\tCoverage\tIntersectionSize\tGenes_in_intersection\tTermSize\tGenes_in_term\n" > "$output_file"

awk -F'\t' -v save_dir="$save_dir" -v out_file="$output_file" '
	# load the Map File (GeneID -> Symbol and Uniprots)
	NR==FNR {
		if (FNR > 1 && $1 != "") {
			gene_ids[$1] = $1
			id_to_sym[$1] = $3
			id_to_uni[$1] = $2
			# keep a list of input of unique symbols
			input_symbols[$3] = $1
		}
		next
	}

	# load the enriched terms
	FILENAME == ARGV[2] {
		if (FNR > 1) {
			term_id = $1
			source = $4
			# skip restricted sources
			if (source == "KEGG" || source == "TF") next

			# store name and source
			active_terms[term_id] = $2  # Name
			term_source[term_id] = source
		}
		next
	}

	# process the GMT File
	FILENAME == ARGV[3] {
		term_id = $1
		if (term_id in active_terms) {
			name = active_terms[term_id]
			src = term_source[term_id]
			
			# sanitize paths
			s_term = term_id; gsub(/:/, "_", s_term)
			s_name = name

			# replace EVERYTHING except letters, numbers, underscores, and dashes
			gsub(/[^a-zA-Z0-9_-]/, "_", s_name) 
			gsub(/__+/, "_", s_name)			# Collapse multiple underscores
			gsub(/^_|_$/, "", s_name)			# Trim underscores from edges
			
			term_path = save_dir "/" src "/annotations/" s_term "_" s_name
			
			# create directory for this term (use \047 as single quotes in system call)
			system("mkdir -p \047" term_path "\047")
			
			# intersection and term size counters, and gene lists
			inter_size = 0; term_size = 0; inter_str = ""; term_str = ""
			inter_file = term_path "/genes_in_intersection"
			term_file = term_path "/genes_in_term"
			
			print "GeneID\tGeneSymbol\tUniprots" > inter_file
			
			# columns 3 to end are genes in the gprofiler gmt file
			for (i=3; i<=NF; i++) {
				gene = $i
				if (gene == "") continue
				term_size++
				term_str = (term_str == "" ? "" : term_str " ") gene
				print gene > term_file
				
				# check if gene symbol is in input symbols (intersection)
				if (gene in input_symbols) {
					gid = input_symbols[gene]
					inter_size++
					inter_str = (inter_str == "" ? "" : inter_str " ") gene
					print gid "\t" id_to_sym[gid] "\t" id_to_uni[gid] >> inter_file
				}
			}
			
			# calculate coverage
			coverage = (term_size > 0 ? inter_size / term_size : 0)
			
			# append to final file
			printf "%s\t%s\t%s\t%.4f\t%d\t%s\t%d\t%s\n", 
				term_id, name, src, coverage, inter_size, inter_str, term_size, term_str >> out_file
			
			# close per-term files to avoid "too many open files" error
			close(inter_file)
			close(term_file)
		}
	}
' "$map_file" "$enriched_fields_file" "$gmt_file"

if [ $? -eq 0 ]; then
	printf "Processing successful. Output saved to '%s'.\n" "$output_file"
else
	printf "❌ [MODULE 3] Error: Processing raw results failed.\n"
	exit 1
fi