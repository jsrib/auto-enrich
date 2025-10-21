import json
import csv
from anytree import Node, RenderTree, AsciiStyle
from anytree.exporter import DotExporter
import pydot
import argparse
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter

# load all reactome hierarchy from json
def load_reactome_hierarchy(json_file):
	with open(json_file, "r", encoding="utf-8") as f:
		return json.load(f)

# load set of enriched pathways from csv
def load_enriched_ids(csv_file):
	enriched_ids = set()
	with open(csv_file, newline='', encoding='utf-8') as f:
		reader = csv.reader(f)
		for row in reader:
			if row:
				raw_id = row[0].strip()
				# Keep only part after first ":" if present
				clean_id = raw_id.split(":", 1)[-1]
				enriched_ids.add(clean_id)
	return enriched_ids

# build all reactome tree
def build_full_tree(data, parent=None):
	nodes = []
	for item in data:
		node = Node(item["id"], parent=parent)
		node.label = item["name"]
		build_full_tree(item.get("children", []), node)
		nodes.append(node)
	return nodes

# extract subtrees of enriched pathways
def extract_enriched_tree(full_nodes, enriched_ids):
	enriched_nodes = []

	def dfs(node):
		if node.name in enriched_ids:
			enriched_nodes.append(node)
		for child in node.children:
			dfs(child)

	for root in full_nodes:
		dfs(root)

    # new enriched nodes
	enriched_map = {node.name: Node(node.name, label=node.label) for node in enriched_nodes}

    # link each enriched node to ancestor
	for node in enriched_nodes:
		ancestor = node.parent
		while ancestor and ancestor.name not in enriched_map:
			ancestor = ancestor.parent
		if ancestor and ancestor.name in enriched_map:
			enriched_map[node.name].parent = enriched_map[ancestor.name]

	return [n for n in enriched_map.values() if n.is_root]

# print enriched tree ascii
def print_ascii_tree(roots, filename="enriched_tree_ascii.txt"):
	lines = []
	for root in roots:
		for pre, _, node in RenderTree(root, style=AsciiStyle()):
			lines.append(f"{pre}{node.name} ({getattr(node, 'label', '')})")
	# print("\n".join(lines))   #terminal print
	with open(filename, "w", encoding="utf-8") as f:
		f.write("\n".join(lines))
	print(f"ASCII tree saved to {filename}")
	return lines

# save to pdf
def save_ascii_to_pdf(lines, pdf_filename="enriched_tree_ascii.pdf"):
	c = canvas.Canvas(pdf_filename, pagesize=letter)
	width, height = letter

	c.setFont("Courier", 10)    #(font, margin)
	line_height = 12
	y = height - 40  # top margin

	for line in lines:
		if y < 40:  # new page if out of space
			c.showPage()
			c.setFont("Courier", 10)
			y = height - 40
		c.drawString(40, y, line)
		y -= line_height

	c.save()
	print(f"PDF saved: {pdf_filename}")

# export enriched tree to dot and png
def export_dot_and_png(roots, dot_filename="enriched_tree.dot", png_filename="enriched_tree.png"):
	synthetic_root = Node("Enriched Pathways")
	for root in roots:
		root.parent = synthetic_root

	DotExporter(synthetic_root).to_dotfile(dot_filename)
	print(f"DOT file saved: {dot_filename}")

	(graph,) = pydot.graph_from_dot_file(dot_filename)
	graph.write_png(png_filename)
	print(f"PNG file saved: {png_filename}")

def main():
	parser = argparse.ArgumentParser(description="Build Reactome enriched pathway tree.")
	parser.add_argument("json", help="Reactome hierarchy JSON file")
	parser.add_argument("csv", help="CSV file with enriched IDs one FIRST column.")

	args = parser.parse_args()

	hierarchy_data = load_reactome_hierarchy(args.json)
	enriched_ids = load_enriched_ids(args.csv)

	full_roots = build_full_tree(hierarchy_data)
	enriched_roots = extract_enriched_tree(full_roots, enriched_ids)

	# call once and reuse lines
	lines = print_ascii_tree(enriched_roots)
	save_ascii_to_pdf(lines)
	export_dot_and_png(enriched_roots)

if __name__ == "__main__":
	main()
