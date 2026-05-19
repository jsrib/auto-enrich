#!/bin/bash
set -eo pipefail

if [ $# -lt 2 ]; then
    printf "Usage: %s <dir1> <dir2> ...\n" "$0"
    exit 1
fi

# tools dictionaries
declare -A tools=(
    [gprof]="gprofiler"
    [ptr]="panther"
    [gsea]="gsea"
)
declare -A tools_dirs
declare -A found_files

# assign input directories to tools
for dir in "$@"; do
    matched=false
    for key in "${!tools[@]}"; do
        if [[ "$dir" == *"${tools[$key]}"* ]]; then
            tools_dirs[$key]="$dir"
            matched=true
            break
        fi
    done
    [[ "$matched" == false ]] && echo "Warning: No match found for $dir"
done

target_file_fields="enrichment_fields.tsv"

# safely locate files for passed tools
active_tools=()
echo "Checking for $target_file_fields in identified directories..."
for key in "${!tools_dirs[@]}"; do
    dir="${tools_dirs[$key]}"
    file=$(find "$dir" -maxdepth 2 -name "$target_file_fields" -print -quit)
    if [[ -n "$file" ]]; then
        found_files[$key]="$file"
        active_tools+=("$key") # Register this tool as active
    else
        echo "❌ [MODULE 7] Error: '$target_file_fields' not found for $key in $dir"
        exit 1
    fi
done

#check if the tool is in found_files before trying to awk it
# gprofiler name column ($2) and source column ($4)
if [[ -n "${found_files[gprof]}" ]]; then
    awk -F"," 'BEGIN {OFS="\t"} /GO_MF|GO_BP|GO_CC|REAC/ { print toupper($2), toupper($4) }' "${found_files[gprof]}" > gprof_terms
fi

# panther name ($2), source ($3), FDR($5), diretion ($7, positive; "pos")
if [[ -n "${found_files[ptr]}" ]]; then
    awk -F"," 'BEGIN {OFS="\t"} $5 < 0.05 && $7 == "+" && /GO_MF|GO_BP|GO_CC|REAC/ { print toupper($2), toupper($3) }' "${found_files[ptr]}" > ptr_terms
fi

# gsea name ($1) and phenotype/direction ($3)
if [[ -n "${found_files[gsea]}" ]]; then
    awk -F"," 'BEGIN {OFS="\t"} (/GOMF|GOBP|GOCC|REACTOME/) && $3 == "pos" {
        term = $1; prefix = substr(term, 1, index(term, "_") - 1); rest = substr(term, index(term, "_") + 1);
        gsub(/_/, " ", rest); gsub(/GOBP/, "GO_BP", prefix); gsub(/GOMF/, "GO_MF", prefix); gsub(/GOCC/, "GO_CC", prefix); gsub(/REACTOME/, "REAC", prefix);
        print toupper(rest), toupper(prefix)
    }' "${found_files[gsea]}" > gsea_terms
fi

# report generation
> report
declare -A totals

# Calculate totals dynamically for whatever tools exist
for tool in "${active_tools[@]}"; do
    totals[$tool]=$(wc -l < "${tool}_terms")
    echo "Total number of GO terms and pathways by ${tools[$tool]}: ${totals[$tool]}" >> report
done

# dynamically calculate pairwise pntersections & Jaccard (for N tools)
num_active=${#active_tools[@]}
for (( i=0; i<num_active; i++ )); do
    for (( j=i+1; j<num_active; j++ )); do
        t1="${active_tools[$i]}"
        t2="${active_tools[$j]}"
        
        sim=$(comm -12 <(sort "${t1}_terms") <(sort "${t2}_terms") | wc -l)
        echo "Number of similar terms between $t1 and $t2: ${sim}" >> report
        
        # prevent division by zero
        denom=$(( totals[$t1] + totals[$t2] - sim ))
        if [ "$denom" -gt 0 ]; then
            jacc=$(echo "scale=6; $sim / $denom" | bc)
        else
            jacc="0.000000"
        fi
        echo "Jaccard similarity between $t1 and $t2: ${jacc}" >> report
    done
done

# cross ALL active streams for exact common terms dynamically
cat_files=""
for tool in "${active_tools[@]}"; do
    cat_files="$cat_files ${tool}_terms"
done

# The awk '$1 == n' dynamically checks that a term appeared in ALL active tools
cat $cat_files | sort | uniq -c | awk -v n="$num_active" '$1 == n { $1=""; sub(/^ /, ""); print }' > common_terms.txt

sim_all=$(wc -l < common_terms.txt)
echo "Number of similar terms across all $num_active tools: ${sim_all}" >> report

# Output final report to screen
echo -e "\n=== ENRICHMENT ANALYSIS INTERSECTION REPORT ==="
cat report

# Cleanup intermediate files safely (only deletes what was actually created)
rm -f *_terms report