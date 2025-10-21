import json
import urllib.request
from collections import defaultdict
import sys

# URLs to Reactome data
RELATIONS_URL = "https://reactome.org/download/current/ReactomePathwaysRelation.txt"
PATHWAYS_URL = "https://reactome.org/download/current/ReactomePathways.txt"

# Local cache filenames
relations_file = "ReactomePathwayRelation.txt"
pathways_file = "ReactomePathways.txt"

# Override defaults with command-line arguments
# Usage: python script.py [species] [output_file]

# Download function
def download_file(url, dest):
	print(f"Downloading {url} ...")
	urllib.request.urlretrieve(url, dest)
	print(f"Saved to {dest}")

# Build hierarchy
def build_hierarchy(species_filter, output_file):
	download_file(RELATIONS_URL, relations_file)
	download_file(PATHWAYS_URL, pathways_file)
	print(f"CHECK: Getting {species_filter} hierarchy")

	# Load pathway names and filter species
	id_to_name = {}
	with open(pathways_file, encoding="utf-8") as f:
		for line in f:
			parts = line.strip().split("\t")
			if len(parts) >= 3:
				pid, name, species = parts[:3]
				if species == species_filter:
					id_to_name[pid] = name

	# Build adjacency list
	children_map = defaultdict(list)
	all_nodes = set()
	with open(relations_file, encoding="utf-8") as f:
		for line in f:
			parent, child = line.strip().split("\t")
			if parent in id_to_name and child in id_to_name:
				children_map[parent].append(child)
				all_nodes.update([parent, child])

	# Find roots (nodes never appearing as child)
	children_set = {c for childs in children_map.values() for c in childs}
	roots = [node for node in all_nodes if node not in children_set]

	# Recursive tree building
	def build_tree(node):
		return {
			"id": node,
			"name": id_to_name.get(node, node),
			"children": [build_tree(child) for child in children_map.get(node, [])]
		}

	hierarchy = [build_tree(root) for root in roots]

	# Save JSON
	with open(output_file, "w", encoding="utf-8") as out:
		json.dump(hierarchy, out, indent=2)
	print(f"Hierarchy saved to {output_file}")

# Main
if __name__ == "__main__":
	import sys
	species = sys.argv[1]   # e.g., "Mus musculus"
	outfile = sys.argv[2]   # e.g., "reactome_mus.json"
	build_hierarchy(species, outfile)
