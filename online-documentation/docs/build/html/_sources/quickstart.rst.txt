**Quickstart**
==============

auto-Enrich is a Docker-based pipeline that automates gene set
enrichment analysis using **g:Profiler**, **PANTHER**, and **GSEA**. It
integrates preparation, enrichment, and post-processing into a modular
framework, where each of the 8 modules (:ref:`reference table <index_table>`) 
can be run independently or combined into full workflows.

The pipeline supports two input types:

- **Gene Identifiers lists** (for g:Profiler and PANTHER)

- **Expression matrices** (for Gene lists preparation, GSEA Classic or
  Preranked)

At minimum, you need:

- A **pipeline configuration file** (defining modules, species, and sources) named **config0**

- One **input file** (gene list or expression matrix)

auto-Enrich streamlines:

- Extracting differentially expressed genes

- Mapping Gene IDs

- Running g:Profiler and PANTHER enrichment tests

- Preparing inputs and running GSEA

- Filtering and plotting enrichment results

**Installation**
----------------

The auto-Enrich pipeline runs in any computing environment with Docker installed. 
It is distributed as part of the `pegi3s Bioinformatics Docker Images Project <http://bdip.i3s.up.pt/>`_, 
and the corresponding image is available at: `<https://hub.docker.com/r/pegi3s/auto-enrich>`_. 
That page also provides a short guide for installing Docker on both Linux and Windows systems.

**Run command**
---------------

After filling in the configuration files and making sure the input files
are present, the user should run the following command to use the Docker
image of the pipeline:

.. code-block::

    docker run --rm -v /your/working/directory:/data pegi3s/auto_enrich

A mounted directory structure, where you should **change your/working/directory** to your data directory.

**Minimal config example**
--------------------------

This minimal configuration demonstrates the simplest way to run
**auto-Enrich** for Over-Representation Enrichment Analysis. By
specifying only the essential variables in **config0**, the pipeline
configuration file.  This configuration file and inputs must be place 
in the mounted directory /data.

Minimal configuration setup in ``config0`` (# are comments):

.. code-block:: ini

  tools='2,3,4'               # Specify the tools to run.
  species='mus_musculus'      # Indicate the target species name.
  gene_list='gene_list'       # Name of the Gene Identifiers list file 

**What happens?**

The pipeline maps input Gene IDs (Module 2) and performs enrichment
using both **g:Profiler** (Module 3) and **PANTHER** (Module 4). With
this setup and a single gene list placed in the /data directory, users
can quickly test the pipeline and generate basic enrichment results with
minimal configuration effort.

**Expected results**
--------------------

Enrichment outputs from **g:Profiler** (Module 3) and **PANTHER**
(Module 4) are saved in /gprofiler and /panther, with one results
subdirectory for the input gene list.

Example of gProfiler results in the mounted directory (/data):

.. code-block:: text

  /data
  └── gprofiler
      └── gene_list
          └── results
              ├── short_results.csv
              ├── long_results.csv
              ├── terms_annotations_results.csv
              └── REAC
                  └── terms_annotations
                      ├── REAC:R-MMU-76002
                      │   ├── genes_in_list
                      │   └── genes_in_term
                      ├── REAC:R-MMU-76005
                      ├── ...
                      └── REAC:R-MMU-6798695

Each results directory includes:

- **short_results.csv** → key fields (term ID, name, p-value, source)
  for quick review.

- **long_results.csv** → full enrichment details (IDs, description,
  p-values, fold enrichment, parent terms, etc.).

- **terms_annotations_results.csv** → consolidated summary with enriched
  terms, gene counts, and gene memberships.

Per-source subdirectories contain the same outputs restricted to that source, plus per-term annotation folders with:

- **genes_in_list** → input genes linked to the enriched term

- **genes_in_term** → full enriched term annotations 
