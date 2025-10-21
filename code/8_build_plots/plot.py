import matplotlib.pyplot as plt
import pandas as pd
import sys

title = sys.argv[1] if len(sys.argv) > 1 else "GeneIDs Map by Group"

data = []

with open('tmp_term') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        info, value = line.rsplit(maxsplit=1)
        value = int(value)
        if '-' in info:
            fields = info.split('-')
			# control-day1-upreg
            if len(fields) >= 3:
                sample = f"{fields[0]}-{fields[1]}"
                group = fields[2].split('_')[0]
            # control-day1
            elif len(fields) == 2:
                sample = f"{fields[0]}-{fields[1]}"
                group = None
            else:
                sample = fields[0]
                group = None
        else:
            # simple case
            sample = info
            group = None
        data.append((sample, group, value))

df = pd.DataFrame(data, columns=['sample', 'group', 'value'])

sample_order = df['sample'].drop_duplicates().tolist()
pivot = df.pivot(index='sample', columns='group', values='value').loc[sample_order]

color_map = {
	"up": "blue",
	"down": "orange"
}

ax = pivot.plot(
	marker='o',
	linewidth=2,
	color=[color_map.get(col, "black") for col in pivot.columns]
)

plt.xlabel('Time points')
plt.ylabel('Number of genes')
plt.title(title)
plt.xticks(rotation=45, ha='right')
plt.tight_layout()
plt.legend(title='Group')
plt.savefig("my_plot.pdf", bbox_inches='tight')
