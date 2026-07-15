#!/bin/bash

if [ $# -ne 3 ]; then
	printf "Usage: %s <config> <input_conditions> <output>\n" "$0"
	exit 1
fi

source "$1"
input_file="$2"
output_file="$3"

if [ ! -f "${input_file}" ]; then
	printf "❌ [MODULE 1] Input File Missing: Input expression matrix file '%s' not found for threshold filtering.\n" "${input_file}" >&2
	exit 1
fi

if [ -z "$expression_min" ] && [ -z "$expression_max" ]; then
	printf "❌ [MODULE 1] Configuration Error: Variable 'expression_min' and 'expression_max' are undefined or empty.\n" >&2
	exit 1
fi

awk -v gene_col="$gene" -v min="$expression_min" -v max="$expression_max" -v out="$output_file" '
BEGIN {
	FS=OFS="\t"
}
NR==1 {
	for (i=1;i<=NF;i++) {
		if ($i ~ /^log2_cond/) {
			cond_idx[++ncond] = i
			cond_name[ncond] = $i
		}
	}
	# add to header
	eval_header=$0
	for (i=1;i<=ncond;i++) eval_header = eval_header OFS "evaluation_" cond_name[i]
	print eval_header > out
	next
}
{
	# loop over condition
	eval_flags=""
	gene = $(gene_col)
	for (c=1;c<=ncond;c++) {
		val=$cond_idx[c]

		# remove log2_ for save name
		save_name = cond_name[c]
		sub(/^log2_/, "", save_name)

		prefix = (min != "" && max != "" ? "in_range" : (min != "" ? "overexp" : "underexp"))
		gname=sprintf("%s_%s_genes_list", prefix, save_name)
		
		valid=1
		if (min != "" && val <= min) valid=0
		if (max != "" && val >= max) valid=0

		if (valid) {
			print gene >> gname
			eval_flags = eval_flags OFS "1"
		} else {
			eval_flags = eval_flags OFS "0"
		}
	}
	print $0 eval_flags >> out
}
END {
	# unique gene lists
	for (c=1;c<=ncond;c++) {
		save_name = cond_name[c]
		sub(/^log2_/, "", save_name)
		
		prefix = (min != "" && max != "" ? "in_range" : (min != "" ? "overexp" : "underexp"))
		gname=sprintf("%s_%s_genes_list", prefix, save_name)

		if ((getline < gname) > 0) {
			close(gname)
			cmd="sort -u " gname " -o " gname
			system(cmd)
		}
	}
}
' "$input_file"
