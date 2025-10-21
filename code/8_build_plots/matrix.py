import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import sys
import os

if len(sys.argv) < 2 or len(sys.argv) > 3:
    print(f"Usage: python {sys.argv[0]} <gene_matrix_file> [plot_title]")
    sys.exit(1)

input_file = sys.argv[1]
filename = os.path.basename(input_file)

plot_title = sys.argv[2] if len(sys.argv) == 3 else filename.split('.', 1)[1] if '.' in filename else filename

df = pd.read_csv(input_file, sep="\t")
df_plot = df.iloc[:-1, 2:]
df_plot.index = df['Sample'][:-1]

if df_plot.empty:
    print(f"Error: gene matrix is empty after preprocessing. Skipping term {plot_title}")
    sys.exit(1)

# color-code
color_matrix = pd.DataFrame(index=df_plot.index,
                            columns=df_plot.columns,
                            dtype=object)

for idx in df_plot.index:
    if "down" in idx:
        color_matrix.loc[idx] = df_plot.loc[idx].replace({1: 'orange', 0: 'white'})
    elif "up" in idx:
        color_matrix.loc[idx] = df_plot.loc[idx].replace({1: 'blue', 0: 'white'})
    else:
        color_matrix.loc[idx] = df_plot.loc[idx].replace({1: 'gray', 0: 'white'})

fig, ax = plt.subplots(figsize=(8,6))

sns.heatmap(df_plot*0, annot=False, linewidths=0.1, linecolor="black",
                 cbar=False, square=False, cmap=["white"], ax=ax)

for y, sample in enumerate(color_matrix.index):
    for x, gene in enumerate(color_matrix.columns):
        rect = mpatches.Rectangle((x,y), 1, 1,
                                  facecolor=color_matrix.loc[sample, gene],
                                  edgecolor='black')
        ax.add_patch(rect)

ax.set_xticklabels(ax.get_xticklabels(), rotation=90)
ax.set_yticklabels(ax.get_yticklabels(), rotation=0)
ax.set_xlabel("Genes")
ax.set_ylabel("Time points")
ax.set_title(plot_title, pad=30)

orange_patch = mpatches.Patch(color='orange', label='Down-regulated')
blue_patch   = mpatches.Patch(color='blue', label='Up-regulated')
fig.legend(handles=[orange_patch, blue_patch],
           fontsize=8,
           loc='upper center',
           bbox_to_anchor=(0.5, 0.93),  # adjust vertical position
           ncol=2,
           frameon=False)

plt.subplots_adjust(top=0.85)

fig.tight_layout()
fig.savefig("my_matrix.pdf", bbox_inches="tight")
