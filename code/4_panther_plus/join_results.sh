#!/bin/bash

result_files=($(ls results_*))

if [ ${#result_files[@]} -eq 0 ]; then
	printf "No results\n"
	exit 0
fi

short="short_results.csv"
long="long_results.csv"

printf "TermID,Name,P-Value_FDR,Plus_Minus,Source\n" > $short
printf "TermID,Name,P-Value,P-Value_FDR,Fold_Enrichment,Plus_Minus,Source,ListCount,TermCount\n" > $long

for file in "${result_files[@]}"; do
	success=true
	# short
	awk -F',' 'NR>1 {print $1 "," $2 "," $4 "," $6 "," $7}' "$file" >> $short
	if [ $? -ne 0 ]; then
		printf "Error processing short results for %s.\n" "$file"
		success=false
	fi

	# long
	awk -F',' 'NR>1 {print $1 "," $2 "," $3 "," $4 "," $5 "," $6 "," $7 "," $8 "," $9}' "$file" >> $long
	if [ $? -ne 0 ]; then
		printf "Error processing Long result for %s.\n" "$file"
		success=false
	fi

	if [ "$success" = false ]; then
		printf "Error processing results for %s.\n" "$file"
		exit 1
	fi
done
