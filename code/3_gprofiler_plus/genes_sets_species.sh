#!/bin/bash
set -euo pipefail

if [ $# -ne 2 ]; then
	printf "Usage: $0 <species> <output_name>\n"
	exit 1
fi

species="$1"  	#gprofiler curl id (from organism index file [id])
output="$2"

# Configuration
url="https://biit.cs.ut.ee/gprofiler/static/gprofiler_${species}.name.zip"
zip_file="gprofiler_${species}.name.zip"
temp_dir="gprof_tmp"

printf "Starting GMT update from zip archive...\n"

if wget -q -O "$zip_file" "$url"; then
	printf "Downloaded zip: %s\n" "$zip_file"
else
	printf "❌ [MODULE 3] Error: Failed to download zip from %s\n" "$url" >&2
	exit 1
fi

{
	echo "!Source: g:Profiler (https://biit.cs.ut.ee/gprofiler/)"
	echo "!Species_ID: $species"
	echo "!Generation_Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
	echo "!Generated_by: auto-Enrich Pipeline"
	echo "!Description: Aggregated GMT files containing pathway and functional annotations."
	echo "!Note: This file is a concatenation of all category-specific .gmt files provided by g:Profiler for this species."
	echo "!License: g:Profiler data is typically subject to the terms of the individual source databases."
} > "$output"

# extract .gmt files
mkdir -p "$temp_dir"
printf "Extracting files...\n"
unzip -q -o "$zip_file" -d "$temp_dir"

# merge .gmt files into one
printf "Merging .gmt files into %s...\n" "$output"
find "$temp_dir" -name "*.gmt" -exec cat {} + >> "$output"

rm -rf "$temp_dir" "$zip_file"

if [[ -s "$output" ]]; then
	printf "Success! Final GMT file created: %s\n" "$output"
else
	printf "❌ [MODULE 3] Error: Resulting GMT file is empty.\n" >&2
	exit 1
fi
