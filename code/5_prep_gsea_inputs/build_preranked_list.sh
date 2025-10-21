#!/bin/bash

if [ "$#" -ne 1 ]; then
	printf "Usage: %s <config>\n" "$0"
	exit 1
fi

config="$1"
sed -i 's/\r$//' "$config"	# ensure no /r

source "$config"

if [[ -z "/data/$input" || -z "$gene" ]]; then
	printf "Error: Config file must define 'input' and 'gene'\n"
	exit 1
fi

header=$(head -n 1 "/data/$input" | tr -d '\r')
IFS=$'\t' read -ra columns <<< "$header"

# col idx array
declare -A col_indices
for i in "${!columns[@]}"; do
	col="${columns[$i]}"
	col_indices["$col"]=$((i + 1))
done

gene_col="${col_indices[$gene]}"
if [[ -z "$gene_col" ]]; then
	printf "Error: Gene column '%s' not found\n" "$gene"
	exit 1
fi

# get each formula
for varname in "${!formula@}"; do
	formula_name="$varname"
	formula_body="${!varname}"

	if [[ -z "$formula_body" ]]; then
		printf "Warning: Skipping empty %s\n" "$formula_name"
		continue
	fi

	# cols names array
	groups=()
	for colname in "${!col_indices[@]}"; do
		if grep -q "\b${colname}\b" <<< "$formula_body"; then
			groups+=("$colname")
		fi
	done

	# output file names
	if [ "${#groups[@]}" -ge 2 ]; then
		group1="${groups[0]}"
		group2="${groups[1]}"
		outfile="logFC_${group1}_${group2}.rnk"
	else
		outfile="logFC_${formula_name}.rnk"
	fi

	# trans formula into awk
	awk_formula="$formula_body"
	for name in "${!col_indices[@]}"; do
		awk_formula=$(echo "$awk_formula" | sed "s/\b$name\b/(\$${col_indices[$name]}+1)/g")
	done

	printf "🔄 Computing %s -> %s\n" "$formula_name" "$formula_body"

	tail -n +2 "/data/$input" | awk -v g="$gene_col" -v OFS="\t" \
		"{ logval = log($awk_formula) / log(2); print \$g, logval; }" | sort -k2,2gr > "$outfile"

	printf "✅ Output saved to %s\n" "$outfile"
done