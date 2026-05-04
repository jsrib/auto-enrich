**Setup and Run**
==========================

.. _config0:

**Pipeline Configuration File (config0)**
-----------------------------------------

The pipeline configuration file, **config0**, defines the core
parameters for running the pipeline, including:

- Which **modules** to execute

- The **target species**

- Selected **data sources** to perform Over-Representation Enrichment
  Analysis (by Modules 3 and 4)

- **Post-processing filtering variables** for enrichment analysis (used
  by Module 7)

- **Post-processing building variables** for enrichment analysis results
  (used by Module 8)

.. Note:: 
  This file must be named **config0** and placed in the assigned
  **data directory** (``/data``).

**Variables defined in the config0 to setup the pipeline execution**

.. table::
  :align: center
  :widths: auto

  +------------+-------------------------------------------+-------------------+
  | Variables  | Description                               | Example           |
  +============+===========================================+===================+
  | tools      | Comma-separated double quoted string of   | '1,2,3,4,5,6,7,8' |
  |            | modules indexes to run (no spaces).       |                   |
  |            |                                           |                   |
  |            | Most important and mandatory!             |                   |
  +------------+-------------------------------------------+-------------------+
  | species    | Target species, either in long form       | 'homo_sapiens'    |
  |            | (homo_sapiens) or short form (hsapiens)   |                   |
  +------------+-------------------------------------------+-------------------+
  | gene_lists | Name of a single gene ID list to run      | 'gene_list'       |
  |            | g:Profiler and PANTHER enrichment.        |                   |
  |            |                                           |                   |
  |            | Not mandatory: one or more gene lists can |                   |
  |            | also be provided in another directory     |                   |
  |            | (/data/prepared_gene_lists).              |                   |
  |            |                                           |                   |
  |            | Useful for running a single, specific     |                   |
  |            | enrichment analysis without relying on    |                   |
  |            | preprocessed expression matrices.         |                   |
  +------------+-------------------------------------------+-------------------+

Example of ``config0`` to run full pipeline (# lines are comments):

.. code-block:: ini

  tools='1,2,3,4,5,6,7,8'
  species='mus_musculus'

  # Modules 3 and 4 variables
  gprofiler_dbs='REAC,GO:CC,GO:MF'
  panther_dbs='GO_SLIM_CC,GO:BP,PANTHER_PATHWAYS'

  # Module 7 variables
  max_annot=500
  min_ratio=10
  max_occur=5
  
  # Module 8 variables
  method='panther'
  dir='standard'
  order='C d1 d3 1w 3w 5w 8w'
  field_separator='-'

**Module defining variables:**

- ``gprofiler_dbs`` and ``panther_dbs`` define data sources to 
  perform enrichment analysis by  Modules 3 and 4 (g:Profiler and PANTHER
  respectively). For a detailed explanation of these variables and
  available data sources, see :ref:`Module 3 section <module3>`  and
  :ref:`Module 4 section <module4>`.

- ``max_occur``, ``min_ratio``, and ``max_annot`` define
  filtering behavior of Module 7 (Filter EA Results). For a detailed
  explanation of these variables, :ref:`Module 7 section <module7>`.

- ``dir``, ``order``, ``field_separator`` and ``method``
  define plotting behavior of Module 8 (Build plots). For a detailed
  explanation of these variables, see :ref:`Module 8 section <module8>`

**Module-specific Configuration Files**

Some modules require their own configuration files, which must also be
placed in the mounted data directory (/data).

**Module-specific configuration files**
 
.. table::
  :align: center
  :widths: auto

  +----------------+-----------------+------------------------------------+
  | **Module**     | **Config File** | **Purpose**                        |
  +================+=================+====================================+
  | Module 1:      | config1         | Defines input expression matrix    |
  | Prepare        |                 | and gene selection parameters.     |
  | Lists          |                 |                                    |
  +----------------+-----------------+------------------------------------+
  | Module 5:      | config5         | Defines method                     |
  | Prepare GSEA   |                 | (Classic/Preranked), group         |
  | Inputs         |                 | assignments, and formulas.         |
  +----------------+-----------------+------------------------------------+
  | Module 6:      | gsea_parameters | Contains key-value pairs for all   |
  | GSEA Plus      |                 | GSEA CLI parameters.               |
  +----------------+-----------------+------------------------------------+

.. Note::
  Modules 1 and 6 also depend on the input data files defined in
  these configs (e.g., expression matrix, GMX file). All input files must
  reside in the mounted data directory /data.

**Working directory structure (/data)**

Example of a correctly populated data directory to run the full pipeline:

::

  /data
  ├── config0
  ├── config1
  ├── config5
  ├── gsea_parameters
  ├── gene_set_file.gmt
  └── expression_matrix.tsv

Data files include the *expression_matrix.tsv*, the gene expression matrix, and *gene_set_file.gmt* from the
`Molecular Signature Database <https://www.gsea-msigdb.org/gsea/msigdb>_` (GSEA).

**Run Command**
---------------

After filling in the configuration files and making sure the input files
are present, the user should run the following command to use the Docker
image of the pipeline:

.. code-block::

    docker run --rm -v /your/working/directory:/data pegi3s/auto_enrich

A mounted directory structure, where the user should **change your/working/directory** to their data directory.

**Behavior**
---------------------

Modules are executed sequentially according to the tools variable in the
**config0** file, allowing flexible customization of the analysis flow.

The pipeline relies on standardized file naming conventions to detect
outputs from previous modules, removing the need for manual
re-specification of inputs. Internal state flags coordinate execution
logic, while embedded sanity checks confirm the presence of required
files and configurations, providing clear error reporting if issues
arise.

- **Modules 1 → 2:**

..

   When **Module 1** generates gene lists from an expression matrix,
   **Module 2** automatically processes each list to map gene
   identifiers. This ensures that all lists are consistently annotated
   and aligned with the target species defined in **config0**, for
   downstream enrichment analyses.

- **Modules 2 → 3/4:**

..

   **Module 3** (g:Profiler Plus) and **Module 4** (PANTHER Plus)
   require the mapped gene information file from **Module 2**. Running
   Module 2 beforehand is **strongly recommended**, since the correct
   species definition in **config0** is also critical to both identifier
   mapping and the selection of the appropriate annotation sets.

- **Modules 5 → 6 (GSEA):**

..

   If **Module 5** is executed, it prepares all necessary GSEA input
   files and automatically updates the *gsea_parameters*
   file with the appropriate key–value pairs. **Module 6** then runs
   either *GSEA Classic* or *GSEA Preranked* using these parameters.
   When multiple pre-ranked lists are available, the pipeline
   iteratively runs GSEA for each, using the gene set file (GMX)
   specified in gsea_parameters. This setup supports fully automated
   batch GSEA analyses without manual reconfiguration.

**Customization of the analysis**
---------------------------------

The pipeline’s modular design allows users to flexibly customize their
analysis by running modules independently and supplying their own
pre-prepared inputs. This makes it possible to:

- **Skip preprocessing steps** (e.g., bypass **Module 1**) and directly
  use custom gene lists for enrichment analysis.

- **Provide mapped identifiers** without rerunning earlier modules.

- **Integrate ready-made GSEA inputs** for direct execution.

- **Apply post-processing filters** to previously generated results.

- **Build time series plots** with previously generated results.

Below, the accepted input formats and placement requirements are
detailed for each relevant module.

**Module 2: Map IDs info** 
^^^^^^^^^^^^^^^^^^^^^^^^^^

**Input:** Pre-prepared gene lists.

**Placement:** Store the lists in a directory named /prepared_gene_lists
inside the assigned /data directory.

**Purpose:** Enables gene identifier mapping directly from one or more
user-provided gene lists.

**Modules 3 and 4: Over-Representation Enrichment Analysis** 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Input:** Pre-mapped gene lists (as produced by Module 2).

**Placement:** Store the mapped gene lists **with suffix \_map** in
/mapped_gene_lists within the assigned /data directory.

**Purpose:** Runs over-representation analyses directly from
user-provided mapped lists.

**Module 6: GSEA** 
^^^^^^^^^^^^^^^^^^

**Input:** Pre-prepared GSEA input files for either **GSEA Classic** or
**GSEA Preranked**.

**Placement:** Files must be located in the /data directory.

**Configuration:** Ensure the filenames are correctly referenced in the
gsea_parameters file (also in /data).

**Purpose:** Runs GSEA directly without the need for Module 5.

**Module 7: Filter EA results** 
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Input:** Enrichment results generated by any enrichment analysis
module.

**Placement:** Keep results in their default module-specific output
directories inside /data.

**Configuration:** Define filtering thresholds (max_occur, min_ratio,
max_annot) in the config0 file.

**Purpose:** Filters and refines results independently of the original
enrichment run (if it follows the exact same structure as outputted by
the pipeline).

**Module 8: Build Plots** 
^^^^^^^^^^^^^^^^^^^^^^^^^

**Input:** Enrichment results generated by any enrichment analysis
module (selected).

**Placement:** Keep results in their default module-specific output
directories inside /data.

**Configuration:** Define plotting parameters (dir, order,
field_separator, method) in the config0 file.

**Purpose:** Builds plots of the enrichment results independently of the
original enrichment run (if it follows the exact same structure as
outputted by the pipeline).

.. _flags:

**Additional Flags**
--------------------

This section describes two optional flags that can be run at any time.
These functions operate on the enrichment analysis results. 

.. Note::

  These flags must be set in the pipeline configuration file, config0.

**Reactome hierarchy flag**  
``reac_hierarchy=y``

- **Purpose**: Builds a hierarchical tree of Reactome enriched pathways when set to ``y``.  
  If empty (default), no tree is built.

- **Source**: Automatically uses results from the Reactome source directories:  
  ``/gprofiler/results/REAC/``.  
  Constructs the hierarchy ASCII tree there.

- **Output files** (inside the REAC source directory):
  
  - ``enriched_tree_ascii.pdf`` – Hierarchy tree of the enriched Reactome pathways (PDF).  
  - ``enriched_tree_ascii.txt`` – Same tree in plain text (TXT).

- **Result file organization**:  
  All short, long, and terms annotation files inside the REAC source directory  
  are ordered according to the hierarchy ASCII tree (top to bottom).

- **Additional column**:  
  A new column (**layer**) is added to all short, long, and terms annotation files.  
  This column is inserted in the 3\ :sup:`rd` position and indicates the pathway’s hierarchical level:

  - ``P0`` – Root or top-level parent pathway  
  - ``P1`` – Second-level parent (child of P0)  
  - ``P2`` – Third-level parent (child of P1)  
  - ``PX`` – Xth-level parent (child of PX-1)  
  - ``C`` – Leaf node (final branch under previous parent)

- **Special case**:  
  If both ``gprofiler`` and ``panther`` directories exist in ``/data``, the tree is built in both locations.


**Gene appearance flag**  
``gene_occurrences=y``

- **Purpose**: Creates a file that analyzes how often genes from the initial list  
  appear across enriched terms.  
  If empty (default), no file is built.

- **Use case**: Helps determine a cutoff for filtering genes based on their frequency.  
  For example, the top 10% of most frequently occurring genes may represent noise  
  or overly generic annotations.

- **Source**: Automatically accesses enrichment results in ``/gprofiler/results``  
  and builds the file there.

- **Output file**: ``gene_occurrences.tsv`` – contains **four columns**:

  - **N_Occurrences** – Number of unique enriched terms a gene appears in.  
  - **N_Genes** – Number of unique genes that appear exactly N times.  
  - **Proportions** – Percentage of all genes that occur exactly N times,  
    calculated as ``(N_Genes / Total_Genes) * 100``.  
  - **Cumulative (CDF)** – Running total of the *Proportions* column, indicating  
    the percentage of genes appearing less than or equal to N times.

- **Additional file**: ``gene_counts`` – contains the occurrence count of every gene.
