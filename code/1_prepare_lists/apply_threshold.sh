#!/bin/bash

if [ $# -ne 2 ]; then
	printf "Usage: %s <config> <conditions_file>\n" "$0"
	exit 1
fi

source "$1"
input_file="$2"

if [ -z "$expression_min" ] && [ -z "$expression_max" ]; then
	printf "Error: No thresholds provided.\n" >&2
	exit 1
fi

awk -v min="$expression_min" -v max="$expression_max" '
BEGIN {
	FS=OFS="\t" #field separator
}
NR==1 {
	for (i=1;i<=NF;i++) {
		if ($i ~ /^cond/) {
			cond_idx[++ncond] = i
			cond_name[ncond] = $i
		}
	}
	eval_header=$0
	for (i=1;i<=ncond;i++) eval_header=eval_header OFS "evaluation_" cond_name[i]
	print eval_header > "evaluation_report.tsv"
	next
}
{
	# loop over condition
	eval_flags=""
	for (c=1;c<=ncond;c++) {
		val=$cond_idx[c]
		fname=sprintf("%s_%s.tsv", (min && max ? "in_range" : (min ? "overexp" : "underexp")), cond_name[c])
		gname=sprintf("%s_genes_%s", (min && max ? "in_range" : (min ? "overexp" : "underexp")), cond_name[c])
		
		valid=1
		if (min && val <= min) valid=0
		if (max && val >= max) valid=0

		if (valid) {
			print $0 >> fname
			print $1 >> gname
			eval_flags = eval_flags OFS "1"
		} else {
			eval_flags = eval_flags OFS "0"
		}
	}
	print $0 eval_flags >> "evaluation_report.tsv"
}
END {
	# unique gene lists
	for (c=1;c<=ncond;c++) {
		gname=sprintf("%s_genes_%s", (min && max ? "in_range" : (min ? "overexp" : "underexp")), cond_name[c])
		cmd="sort -u " gname " -o " gname
		system(cmd)
	}
}
' "$input_file"
