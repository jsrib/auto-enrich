#!/bin/bash

if [ $# -ne 1 ]; then
	printf "Usage: $0 <species>\n"
	exit 1
fi

species="$1"

url="https://biit.cs.ut.ee/gprofiler//static/gprofiler_full_${species}.name.gmt"
wget -O "${species}_gProfiler_annotations.gmt" "$url"

if [ $? -ne 0 ]; then
	printf "Error: downloading the gProfiler Gene Sets file.\n"
	exit 1
fi
