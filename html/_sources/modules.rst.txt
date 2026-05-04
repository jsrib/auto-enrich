**Description**
=======================

.. _module1:

**Module 1: Prepare Gene Lists**
--------------------------------

This module automates the extraction of **over- and under-expressed gene
lists** from an expression matrix. It applies user-defined thresholds
and conditions to identify differentially expressed genes across
experimental groups, eliminating the need for manual preprocessing.

**Purpose**

- Standardize the creation of input gene lists for downstream enrichment
  analyses.

- Automatically generate lists of over- and under-expressed genes based
  on configurable thresholds.

**Inputs:**

- **Expression matrix** (.tsv) containing gene identifiers and
  expression values.

- **Configuration file** (:ref:`config1 <config1>`)  with user-defined variables.

.. Important::
  
  Inputs must be placed in the /data directory.

**Outputs:**

- Gene lists of over- or under-expressed (up- or down-regulated) genes, ready for
  downstream modules (e.g., g:Profiler, PANTHER, GSEA).

.. _config1:

.. Note::

   For more details, see the :ref:`Module 1 Outputs <out1>` section.

**Variables defined in config1 for controlling Module 1**

.. table::
  :align: left
  :widths: auto

  +----------------+-------------------------------+-------------------------+
  | Variable       | Description                   | Example                 |
  +================+===============================+=========================+
  | input          | Name of the input expression  | “expression_matrix.tsv” |
  |                | matrix .tsv file (must be in  |                         |
  |                | /data).                       |                         |
  +----------------+-------------------------------+-------------------------+
  | gene           | Column index, in the input    | 1                       |
  |                | expression matrix file,       |                         |
  |                | containing Gene Identifiers   |                         |
  |                | (IDs).                        |                         |
  +----------------+-------------------------------+-------------------------+
  | control        | Column index, in the input    | 2                       |
  | (optional)     | expression matrix file,       |                         |
  |                | containing the pre-calculated |                         |
  |                | average expression values of  |                         |
  |                | the control samples. Used to  |                         |
  |                | filter isoforms.              |                         |
  +----------------+-------------------------------+-------------------------+
  | avgN           | Column index (or list of      | avg1=2                  |
  |                | indexes), in the input        |                         |
  |                | expression matrix file, for   | avg2=”3,4,5”.           |
  |                | pre-calculated averages or    |                         |
  |                | sample expression values of a |                         |
  |                | group. Supports multiple      |                         |
  |                | groups.                       |                         |
  +----------------+-------------------------------+-------------------------+
  | condN          | Condition formulas comparing  | cond1=“avg1/avg2”       |
  |                | average expression values     |                         |
  |                | between groups. Must use      | cond2=”(avg1 +          |
  |                | previously defined avgN       | avg2)/avg2”             |
  |                | parameters.                   |                         |
  +----------------+-------------------------------+-------------------------+
  | expression_min | Minimum threshold for         | 2                       |
  |                | condition values to mark a    |                         |
  |                | gene as overexpressed.        | In this case, only      |
  |                |                               | genes with values > 2   |
  |                |                               | are considered          |
  |                |                               | over-expressed.         |
  +----------------+-------------------------------+-------------------------+
  | expression_max | Maximum threshold for         | 1                       |
  |                | condition values to mark a    |                         |
  |                | gene as underexpressed.       | In this case only genes |
  |                |                               | with values < 1 are     |
  |                |                               | considered              |
  |                |                               | under-expressed.        |
  +----------------+-------------------------------+-------------------------+
  | select         | Column index, in the input    | 8                       |
  | (priority)     | expression matrix file,       |                         |
  |                | containing pre-evaluated      | Only genes with a value |
  |                | binary values (0 or 1) for    | of 1 are selected.      |
  |                | gene selection.               |                         |
  +----------------+-------------------------------+-------------------------+

**Example config1 file:**

.. code-block:: ini

  input='expression_matrix.tsv'
  gene=1
  control=2
  avg1=2
  avg2='3,4,5'
  cond1='avg1/avg2'
  expression_min=2

.. Warning::

  - Column index starts at 1
  - If both **expression_min** and **expression_max** are defined, only genes within the range are included.
  - The **select** parameter takes **priority** over all other rules: only genes with 1 in the specified column will be kept.

.. _module2:

**Module 2: Map IDs info**
--------------------------

This module standardizes a list of Gene Identifiers (Gene IDs) into a
unified format to ensure compatibility across enrichment tools and
biological databases. By harmonizing identifiers, it enables accurate
cross-referencing and smoother downstream integration.

**Input(s)**

- A list(s) of Gene IDs (raw Gene IDs to be standardized).

**Output(s)**

- **TSV file** with one gene per row, including:

  - Original Gene ID

  - UniProtKB ID

  - Official Gene Symbol

  - Full Gene Name

- **Species-specific cache file**, storing retrieved mappings to speed
  up future runs.

.. Note::

  For more details, see the :ref:`Module 2 Outputs <out2>` section.

**Features**

- Provides extended gene information (uniprots, symbols and full names) for easier interpretation.

- Ensures compatibility with datasets and tools using different identifier standards.

- Uses local caching to avoid redundant queries, improving efficiency when processing multiple lists.

.. _module3:

**Module 3: gProfiler plus**
----------------------------

This module automates enrichment analysis using the **g:Profiler
g:GOSt** tool via its API. It handles sending requests across all or
user-selected annotations sources, applying False Discovery Rate (FDR)
correction, formatting outputs, and mapping annotation terms to genes.

**Supported annotation sources:**

- **CORUM** – Manually annotated protein complexes from mammalian
  organisms.

- **GO:MF** – Gene Ontology Molecular Function branch

- **GO:BP** – Gene Ontology Biological Process branch

- **GO:CC** – Gene Ontology Cellular Component branch

- **HPO** – Human Phenotype Ontology, a standardized vocabulary of phenotypic abnormalities encountered in human disease.

- **HPA** - Human Protein Atlas expression data

- **miRNA** – mirTarBase miRNA targets

- **REAC** – Reactome pathways

- **WP** – WikiPathways

- **KEGG**\ \* – KEGG pathways

- **TRANSFAC**\ \* – Transfac transcription factor binding site
  predictions

.. Note::

  *\KEGG and TRANSFAC are omitted datasources from the terms annotations results file due to licensing issues when downloading the
  combined GMT file archive.*

**Inputs**

- **Mapped gene list(s)** (``.tsv``) generated by *Module 2*, containing:

  - Original Gene ID  
  - UniProtKB ID  
  - Official Gene Symbol  
  - Full Gene Name  

- **Module configuration variables** (defined in :ref:`config0 <config0>`):

  .. code-block:: ini

     species=

  - Specifies the target species for enrichment.  
    Can be defined in short format (e.g., ``hsapiens``, ``mmusculus``)  
    or long format (e.g., ``homo_sapiens``, ``mus_musculus``).

  .. code-block:: ini

     gprofiler_dbs=

  - Lists the annotation sources to include for enrichment (e.g., ``GO:BP, GO:MF, KEGG, Reactome``).  
    Leave empty (default) to include **all** sources.

**Available database keys for gprofiler_dbs (in config0)**

.. table::
  :align: left
  :widths: auto

  +----------------+-----------------------------------------------------+
  | Sources        | Possible Keys (separated by \| )                    |
  +================+=====================================================+
  | GO:CC          | GO:CC|GO_CC|GO CC                                   |
  +----------------+-----------------------------------------------------+
  | GO:BP          | GO:BP|GO_BP|GO BP                                   |
  +----------------+-----------------------------------------------------+
  | GO:MF          | GO:MF|GO_MF|GO MF                                   |
  +----------------+-----------------------------------------------------+
  | REAC           | REAC|REACTOME|REACTOME_PATHWAY|REACTOME PATHWAY     |
  +----------------+-----------------------------------------------------+
  | KEGG\*         | KEGG|KEGG PATHWAYS|KEGG                             |
  |                | PATHWAY|KEGG_PATHWAY|KEGG_PATHWAYS                  |
  +----------------+-----------------------------------------------------+
  | WP             | WP|WIKI PATHWAYS|WIKI                               |
  |                | PATHWAY|WIKI_PATHWAY|WIKI_PATHWAYS                  |
  +----------------+-----------------------------------------------------+
  | TF\*           | TF|TRANSFAC                                         |
  +----------------+-----------------------------------------------------+
  | MIRNA          | MIRNA|MIRTARBASE                                    |
  +----------------+-----------------------------------------------------+
  | HPA            | HPA|HUMAN PROTEIN ATLAS|HUMAN_PROTEIN_ATLAS         |
  +----------------+-----------------------------------------------------+
  | CORUM          | CORUM                                               |
  +----------------+-----------------------------------------------------+
  | HP             | HP|HUMAN PHENOTYPE                                  |
  |                | ONTOLOGY|HUMAN_PHENOTYPE_ONTOLOGY                   |
  +----------------+-----------------------------------------------------+

*\KEGG and TRANSFAC are omitted datasources from the terms annotations results file due to licensing issues when downloading the
combined GMT file archive.*

**Outputs**

The following files and directories are generated after running the g:Profiler enrichment module.

- **Result files (CSV)** — generated for all sources and for each individual source:

  - **short_results.csv** – Summary metrics for quick interpretation.  
  - **long_results.csv** – Complete enrichment results, including all terms and mappings.  
  - **terms_annotations_results.csv** – Enriched terms mapped back to the original gene list.

- **Per-source subdirectories** — one for each annotation source (e.g., GO, KEGG, Reactome):

  - Contain CSV result files specific to that source.  
  - Include subdirectories for each enriched term, each containing:
    - A TSV file with genes from the initial list associated with the term.  
    - A plain text file listing all linked genes from the input list.

- **Species-specific annotation file (GMT format)**  

  A locally cached file containing annotations and pathways used by g:Profiler,  
  downloaded directly from the g:GOSt sources tab.  
  This file enables mapping enriched terms back to the initial gene list.  
  Saved as:

  ``<short_species>_gprofiler_annotations.gmt`` *(e.g., hsapiens_gprofiler_annotations.gmt)*

.. Note::

  For more details, see the :ref:`Module 3 Outputs <out34>` section.

**Features**

- Connects directly to the g:Profiler API, ensuring analysis uses
  current annotations.

- Allows selection of specific annotation sources.

- Applies FDR correction to improve confidence in reported enriched
  terms.

- Caches species-specific GMT files to speed up consecutive runs.

- Organizes results in a clear, hierarchical structure for easy
  exploration and visualization.

- Central run script automates requests, formatting, annotation
  retrieval, and result management, ensuring reproducibility and
  reducing manual errors.

.. _module4:

**Module 4: PANTHER plus**
--------------------------

This module performs functional enrichment analysis using the PANTHER
Classification System via its API. It runs statistical
over-representation tests across all or user-selected annotations
sources, applying False Discovery Rate (FDR) correction to ensure
reliability of the reported terms.

**Supported annotation sources:**

- Gene Ontology (Biological Process, Molecular Function, Cellular
  Component)

- Curated GO-SLIM subset

- Reactome Pathways

- PANTHER Pathways

- PANTHER Protein Class ontology

**Inputs**

- **Mapped gene list(s)** (``.tsv``) generated by *Module 2*, containing:

  - Original Gene ID  
  - UniProtKB ID  
  - Official Gene Symbol  
  - Full Gene Name  

- **Module configuration variables** (defined in :ref:`config0 <config0>`):

  .. code-block:: ini

     species=

  - Specifies the target species for enrichment.  
    Can be defined in short format (e.g., ``hsapiens``, ``mmusculus``)  
    or long format (e.g., ``homo_sapiens``, ``mus_musculus``).

  .. code-block:: ini

     panther_dbs=

  - Lists the annotation sources to include for enrichment (e.g., ``GO:BP, GO:MF, Reactome, PANTHER SPathways``).  
    Leave empty (default) to include **all** sources.

**Available database keys for panther_dbs (in config0)**

.. table::
  :align: left
  :widths: auto

  +-------------------+--------------------------------------------------+
  | Database/Source   | Possible Keys (separated by \| )                 |
  +===================+==================================================+
  | GO:CC             | GO_CC|GO:CC|GO CC                                |
  +-------------------+--------------------------------------------------+
  | GO:BP             | GO_BP|GO:BP|GO BP                                |
  +-------------------+--------------------------------------------------+
  | GO:MF             | GO_MF|GO:MF|GO MF                                |
  +-------------------+--------------------------------------------------+
  | REAC              | REAC|REACTOME|REACTOME_PATHWAY|REACTOME PATHWAY  |
  +-------------------+--------------------------------------------------+
  | PTR_GO_SLIM_CC    | GO_SLIM_CC|GO:SLIM:CC|PANTHER_GO_CC|PANTHER GO   |
  |                   | CC|PANTHER GO:CC|PANTHER GO SLIM CC              |
  +-------------------+--------------------------------------------------+
  | PTR_GO_SLIM_BP    | GO_SLIM_BP|GO:SLIM:BP|PANTHER_GO_BP|PANTHER GO   |
  |                   | BP|PANTHER GO:BP|PANTHER GO SLIM BP              |
  +-------------------+--------------------------------------------------+
  | PTR_GO_SLIM_MF    | GO_SLIM_MF|GO:SLIM:MF|PANTHER_GO_MF|PANTHER GO   |
  |                   | MF|PANTHER GO:MF|PANTHER GO SLIM MF              |
  +-------------------+--------------------------------------------------+
  | PANTHER_PATHWAY   | PANTHER_PATH|PANTHER                             |
  |                   | PATH|PANTHER_PATHWAY|PANTHER PATHWAY             |
  +-------------------+--------------------------------------------------+
  | PANTHER_PC        | PANTHER_PC|PANTHER PC|PANTHER_PC                 |
  +-------------------+--------------------------------------------------+

**Outputs**

The following files and directories are generated after running the PANTHER enrichment module.

- **Result files (CSV)** — produced for all sources and each individual source:

  - **short_results.csv** – Summary metrics for quick interpretation.  
  - **long_results.csv** – Complete enrichment results, including all terms and detailed fields.  
  - **terms_annotations_results.csv** – Enriched terms mapped back to the original gene list.

- **Per-source subdirectories** — one for each annotation source:

  - Contain CSV result files specific to that source.  
  - Include subdirectories for each enriched term, containing:
    - A TSV file listing genes from the initial list associated with the term.  
    - A plain text file with all linked genes from the input list.

**Annotation files** *(species-specific, cached locally for reuse)*

Annotation data are automatically downloaded, processed, and cached locally for reuse.

- **From PANTHER FTP** – GO-SLIM, PANTHER Pathways, and Protein Class annotations.  
  Cleaned and saved as:

  ``<species_prefix>_PTHR19.0_annotations``

- **From Gene Ontology (AmiGO)** – Real-time annotations for:
  - Biological Process (BP)
  - Molecular Function (MF)
  - Cellular Component (CC)

- **From Reactome Database** – Pathway annotations, saved as:

  ``<species_prefix>_REAC_annotations``

.. Note::

  For more details, see the :ref:`Module 4 Outputs <out34>` section.

**Features**

- Direct integration with the PANTHER API for up-to-date enrichmentmresults.

- FDR correction applied to all results.

- Local caching of species-specific annotation files to improve efficiency and reproducibility.

- Organized output structure for easy exploration and downstream use.

- Central run script automates the workflow: API requests, parsing,
  corrections, annotation retrieval, and results organization.

.. _module5:

**Module 5: Prep GSEA inputs**
------------------------------

This module automates the creation of input files required for **Gene
Set Enrichment Analysis (GSEA)**. It transforms a gene expression matrix
into the proper formats for either:

- **GSEA Classic** – uses expression matrices to compare predefined
  sample groups.

- **GSEA Preranked** – uses ranked gene lists derived from user-defined
  formulas.

By handling isoform filtering, formula evaluation, and file formatting,
the module eliminates manual preprocessing steps and ensures
compatibility with GSEA.

**Inputs:**

- **Gene expression matrix (TSV)** – raw input expression matrix file.

- **Configuration file** (:ref:`config5 <config5>`) – module configuraion file
  the specifies the method (classic or preranked), group/sample definitions, formulas, 
  and optional variables.

.. Important::
  
  Inputs must be placed in the /data directory.

**Outputs:**

**For GSEA Classic**

- Formatted expression GCT dataset **(.gct)**

- Phenotype labels CSL file **(.cls)**

- Isoform filtering step, retaining the highest-expressed
  isoform per gene **(optional)** 

**For GSEA Preranked**

- Preranked gene lists generated from user-defined formulas (One or more **.rnk** files)

  - Supports multiple formulas (formula1, formula2, …) to create
    multiple ranked lists in a single run.

  - Values are log2-transformed for consistency.

.. _config5:

.. Note::

  For more details, see the :ref:`Module 5 Outputs <out56>` section.

**Variables defined in config5 for controlling Module 5**

.. table::
  :align: left
  :widths: auto

  +----------------+-----------+--------------------+-------------------------+
  | Parameter      | Method    | Description        | Example                 |
  +================+===========+====================+=========================+
  | method         | both      | Selects workflow:  | “classic”               |
  |                |           | “classic” or       |                         |
  |                |           | “preranked”.       |                         |
  +----------------+-----------+--------------------+-------------------------+
  | input          | both      | Name of expression | “expression_matrix.tsv” |
  |                |           | matrix file (must  |                         |
  |                |           | be in /data).      |                         |
  +----------------+-----------+--------------------+-------------------------+
  | gene           | both      | Column header name | “GeneID”                |
  |                |           | containing gene    |                         |
  |                |           | identifiers (IDs   |                         |
  |                |           | or symbols). Must  |                         |
  |                |           | match MSigDB sets. |                         |
  +----------------+-----------+--------------------+-------------------------+
  | control        | classic   | (Optional) Column  | “2,3,4”                 |
  |                |           | index with average |                         |
  |                |           | expression values  |                         |
  |                |           | of control         |                         |
  |                |           | samples, used for  |                         |
  |                |           | isoform filtering. |                         |
  +----------------+-----------+--------------------+-------------------------+
  | description    | classic   | (Optional) Column  | 2                       |
  |                |           | index with gene    |                         |
  |                |           | descriptions       |                         |
  |                |           | (default = N/A).   |                         |
  +----------------+-----------+--------------------+-------------------------+
  | number_samples | classic   | Total number of    | 8                       |
  |                |           | samples across all |                         |
  |                |           | groups.            |                         |
  +----------------+-----------+--------------------+-------------------------+
  | samples        | classic   | Column indexes of  | “3,4,5,6,7,8,9,10”      |
  |                |           | expression values  |                         |
  |                |           | (comma-separated). |                         |
  |                |           | Must match         |                         |
  |                |           | number_samples.    |                         |
  +----------------+-----------+--------------------+-------------------------+
  | number_groups  | classic   | Number of distinct | 2                       |
  |                |           | groups.            |                         |
  +----------------+-----------+--------------------+-------------------------+
  | group_order    | classic   | Group names and    | “Control 4 Exp 4”       |
  |                |           | counts, matching   |                         |
  |                |           | samples order.     |                         |
  +----------------+-----------+--------------------+-------------------------+
  | formulaN       | preranked | Custom formulas to | formula1=”col1/col2”    |
  |                |           | compute ranked     |                         |
  |                |           | lists, multiple    | formula2=”col2/col1”    |
  |                |           | allowed. Use       |                         |
  |                |           | columns names      |                         |
  |                |           | (**cannot have     |                         |
  |                |           | spaces**) with     |                         |
  |                |           | pre-calculated     |                         |
  |                |           | averages.          |                         |
  +----------------+-----------+--------------------+-------------------------+

**Example configurations of config5 file:**

**To prepare GSEA Classic inputs:**

.. code-block:: ini

    method='classic'
    input='expression_matrix.tsv'
    gene='GeneID'
    control='3,4,5'
    description=2
    samples='3,4,5,6,7,8,9,10'
    number_groups=2
    group_order='Control 4 Exp 4'

**To prepare GSEA Preranked inputs:**

.. code-block:: ini

    method='preranked'
    input='expression_matrix.tsv'
    gene='GeneID'
    formula1='Control_avg / Exp_avg'
    formula2='Exp_avg / Control_avg'

.. Warning::

  - Column indexes are 1-based. 
  - The identifier specified in parameter **gene** must match the
    identifier format of the gene sets used in GSEA (NCBI Entrez IDs or
    Gene Symbols).
  - Group order must match the order of samples listed in `samples`.

.. _module6:

**Module 6: GSEA plus**
-----------------------

This module integrates the **Gene Set Enrichment Analysis (GSEA)**
workflow by wrapping the gsea-cli.sh tool (`GSEA v4.4.0, Broad
Institute <https://www.gsea-msigdb.org/gsea/index.jsp>`_). 
It automates file handling, parameter setup, and results
parsing, making it easier to run **GSEA Classic** or **GSEA Preranked**
analyses.

**Inputs:**

- **Parameter file** (:ref:`gsea_parameters <config6>`): tab-separated key-value pairs
  that define the run settings.

- **Data files**:

  - Expression dataset (.gct or .res)

  - Phenotype labels (.cls)

  - Gene set matrix (.gmt, .gmx, or .grp) or preranked gene list (.rnk)

  - (Optional) Chip annotation file (.chip)

.. Important::
  
  Inputs must be placed in the /data directory.


**Outputs:**

- **CSV results files**

  - **short_results.csv**: Summary metrics for quick interpretation

  - **long_results.csv**: Full enrichment results, including all terms
    and detailed mappings.

  - **terms_annotations_results.csv**: Enriched terms mapped back to the
    original gene list.

- **Per-source subdirectories**, each including:

  - CSV results files for only the source itself

  - Subdirectories for each enriched term, containing:

    - TSV of the genes from the initial list associated with the term

    - Plain text file listing all linked genes from initial list

.. Note::

  For more details, see the :ref:`Module 5 Outputs <out56>` section.

**Example (tab-separated key-values) of gsea_parameters file:**

.. code-block:: text

  res    expression_dataset.gct
  cls phenotype_labels.cls
  gmx m2.all.v2024.1.Mm.entrez.gmt
  collapse    No_Collapse
  chip \*
  nperm  1000
  permute gene_set
  plot_top_x  20
  out results

To perform Gene Set Enrichment Analysis the described parameters in
the following table must be set in the gsea_parameters file that must be present in
the mounted data directory (/data).

.. _config6:

**Mandatory key parameters defined in the gsea_parameters file to run Module 6 GSEA**

.. table::
  :align: left
  :widths: auto

  +------------+-----------------------------------------+--------------------------------------------------------------------------------+
  | Key        | Description                             | Example                                                                        |
  +============+=========================================+================================================================================+
  | res        | Indicate the name of the expression     | expression_dataset.gct                                                         |
  |            | dataset file (GCT or RES format).       |                                                                                |
  +------------+-----------------------------------------+--------------------------------------------------------------------------------+
  | cls        | Indicate the name of the phenotype      | phenotype_labels.cls                                                           |
  |            | labels file (CLS format), of the set    |                                                                                |
  |            | expression dataset file, which can      |                                                                                |
  |            | define either categorical phenotypes    |                                                                                |
  |            | (e.g., tumor vs normal) or continuous   |                                                                                |
  |            | phenotype.                              |                                                                                |
  +------------+-----------------------------------------+--------------------------------------------------------------------------------+
  | gmx        | Indicate the name of the gene set file  | M2.all.v2024.1.Mm.entrez.gmt from Molecular Signature Database `Mouse          |
  |            | (GMT format), such as those provided by | collections <https://www.gsea-msigdb.org/gsea/msigdb/mouse/collections.jsp>`__ |
  |            | Molecular Signature                     |                                                                                |
  +------------+-----------------------------------------+--------------------------------------------------------------------------------+
  | collapse   | Define how gene identifiers are         | No_Collapse                                                                    |
  |            | handled:                                |                                                                                |
  |            |                                         | In this case, no chip annotation file set                                      |
  |            | - Collapse (default): Use the chip file |                                                                                |
  |            |   to convert to gene symbols            |                                                                                |
  |            |                                         |                                                                                |
  |            | - No_Collapse: Use gene symbols as-is;  |                                                                                |
  |            |   no chip file needed                   |                                                                                |
  |            |                                         |                                                                                |
  |            | - Remap_Only: Remap identifiers without |                                                                                |
  |            |   collapsing data                       |                                                                                |
  |            |                                         |                                                                                |
  |            | **Note:** Only use No_Collapse if your  |                                                                                |
  |            | expression dataset already uses the     |                                                                                |
  |            | same gene identifiers as the selected   |                                                                                |
  |            | gene set file (either Gene IDs or Gene  |                                                                                |
  |            | Symbols)                                |                                                                                |
  +------------+-----------------------------------------+--------------------------------------------------------------------------------+
  | chip \*    | (Optional) Indicate the name of the     | -                                                                              |
  | (optional) | chip annotation file that maps array    |                                                                                |
  |            | probe IDs to gene symbols. **Required   |                                                                                |
  |            | if collapse is set to Collapse or       |                                                                                |
  |            | Remap_Only.**                           |                                                                                |
  +------------+-----------------------------------------+--------------------------------------------------------------------------------+
  | out        | Indicate the name of the output         | results                                                                        |
  |            | directory to where the analysis results |                                                                                |
  |            | will be saved. **Default: results.**    |                                                                                |
  +------------+-----------------------------------------+--------------------------------------------------------------------------------+

.. Important::

  - All files assigned to file-based parameters (RES, CLS, GMX and CHIP)
    must be located in the same directory as the parameter file
  - **Gene sets file (GMX)** - Contains one or more gene sets. For each
    gene set, it gives the gene set name and list of features (genes or
    probes) in that gene set. Features can be downloaded in either NCBI
    (Entrez) Gene IDs or Gene Symbols identifiers. Format is GMX, GMT or
    GRP and can be individually downloaded from `Human MSigbDB
    Collections <https://www.gsea-msigdb.org/gsea/msigdb/human/collections.jsp>`__
    or `Mouse MSigDB
    Collections <https://www.gsea-msigdb.org/gsea/msigdb/mouse/collections.jsp>`__,
    or complete collection from `GSEA
    Downloads <https://www.gsea-msigdb.org/gsea/downloads.jsp>`__.
  - **Collapse parameter -** Since the default value of collapse is
    ‘Collapse’ it’s advised to set the parameter value yourself. If not
    set, GSEA falls to the default value which requires the chip
    annotation file, leading to an error if not provided.
  - **Chip annotations files (CHIP) -** Lists each identifier on a
    platform and its matching HGNC Gene Symbol. **Optional** for Gene Set
    Enrichment Analysis. CHIP format can be downloaded from the `GSEA
    Downloads <https://www.gsea-msigdb.org/gsea/downloads.jsp>`__
    (`Human <https://data.broadinstitute.org/gsea-msigdb/msigdb/annotations/human/>`__
    or
    `Mouse <https://data.broadinstitute.org/gsea-msigdb/msigdb/annotations/mouse/>`__
    Chip Annotations files).

**Additional recommended parameters to define in the gsea_parameters file to run Module 6 GSEA**

.. table::
  :align: left
  :widths: auto

  +------------+-------------------------------------------------+----------+
  | Key        | Description                                     | Example  |
  +============+=================================================+==========+
  | permute    | Define the permutation type:                    | gene_set |
  |            |                                                 |          |
  |            | - phenotype **(default):** Shuffles sample      |          |
  |            |   labels. Recommended for datasets with ≥7      |          |
  |            |   samples per group                             |          |
  |            | - gene_set: Randomizes gene sets. Used for      |          |
  |            |   small datasets (<7 samples per group)         |          |
  +------------+-------------------------------------------------+----------+
  | nperm      | Define the number of permutations for           | 1000     |
  |            | statistical significance (e.g., 1000            |          |
  |            | recommended, start with 10 to test setup).      |          |
  |            |                                                 |          |
  |            | **Default: 1000**                               |          |
  +------------+-------------------------------------------------+----------+
  | plot_top_x | Define the number of top enriched gene sets,    | 20       |
  |            | highest normalized enrichment score, to include |          |
  |            | in result plots.                                |          |
  |            |                                                 |          |
  |            | **Default: 20**                                 |          |
  +------------+-------------------------------------------------+----------+

**Additional parameters**

This module supports nearly all options from the **GSEA CLI**, including:

- ``metric``, ``scoring_scheme``, ``rpt_label``,
  ``sort``, ``set_max``, ``set_min``, ``norm``,
  ``rnd_seed``, ``zip_report``, ``create_svgs``, and others.

.. Note::

  See the GSEA CLI User Guide for a complete reference `GSEA CLI User
  Guide <https://www.gsea-msigdb.org/gsea/doc/GSEAUserGuideTEXT.htm#_Metrics_for_Ranking>`_.

.. _module7:

**Module 7: Filter EA results**
-------------------------------

This module filters enrichment analysis (EA) results to remove overly
common or biologically unspecific terms and genes. It applies
user-defined thresholds to refine the final annotations, retaining only
the most relevant associations for downstream interpretation.

**Input:**

- A directory containing enrichment analysis results, including the term
  annotations file

- **Filter variables** – to be defined in the
  pipeline configuration file, ``config0``.

.. Important::
  
  Inputs must be placed in the /data directory.

**Output:**

- **terms_annotations_filtered.csv** – A filtered version of term
  annotations results CSV file with only the most relevant and specific
  results retained. This file is saved inside the enrichment results
  directory of each tool.

.. Important::
  At least one of the variables described in following table must be set in the
  **config0** file (pipeline configuration file).

**Variables defined in the config0 to control execution of Module 7**

.. table::
  :align: left
  :widths: auto

  +------------+-----------------------------------------------+---------+
  | Variable   | Description                                   | Example |
  +============+===============================================+=========+
  | max_annot  | Maximum number of genes allowed to be         | 500     |
  |            | annotated to a term (Max. Term_size).         |         |
  |            | Enriched terms exceeding this are excluded.   |         |
  +------------+-----------------------------------------------+---------+
  | min_ratio  | Minimum ratio (0–100) of genes from the       | 20      |
  |            | initial list in the term compared to all      |         |
  |            | genes annotated to that term. Terms below     |         |
  |            | this ratio are excluded.                      |         |
  +------------+-----------------------------------------------+---------+
  | max_occur  | Maximum number of terms in which a gene may   | 5       |
  |            | appear. Genes exceeding this threshold are    |         |
  |            | removed from the genes_in_list field.         |         |
  +------------+-----------------------------------------------+---------+

**Example:**

Suppose an enrichment results file contains:

- Gene **TP53** (from the initial gene lists) appearing in **15 terms**.

- Term **GO:0008150** (biological process) annotated with **1200
  genes**.

- Term **GO:0006915** (apoptotic process) where **8 of 50 annotated
  genes** are in the user’s input list (ratio = 16%).

With the following parameters:

.. code-block:: ini

  max_annot=500
  min_ratio=20
  max_occur=10

The module would:

- **Exclude GO:0008150** (too broad, annotated with 1200 genes,
  exceeding max_annot=500).

- **Exclude GO:0006915** (ratio 16% < threshold 20%).

- **Remove TP53** from all term annotations (since it occurs in 15
  terms, exceeding max_occur=10).

Only terms and gene associations passing all active filters remain in
the final output.

.. Hint:: 

  - The **best thresholds depend on the dataset** and **research goal**.
    Users should first inspect unfiltered results to identify suitable
    cutoffs.

  - To guide parameter choice, a **gene occurrences flag** exists
    to generate a **TSV file** showing gene frequency across terms (see
    :ref:`Additional Flags <flags>` section  for more detail on this).

.. _module8:

**Module 8: Build Plots**
-------------------------

This module helps you see how biological processes change over time by
analyzing enrichment results across a temporal series. It tracks which
genes are switched on or off at each timepoint and shows how their
involvement in specific pathways or functions grows or shrinks.
It gathers several enrichment analysis results built has a time series
of both up- and down-regulated genes and analyzes which ones are 
annotated in enriched terms at each timepoint, counts them and produces 
two visual outputs.

**Inputs:**

- Parameters configuration such as samples selection and order

- Enrichment analysis (in data directory /data):

  - Enrichment results (/panther or /gprofiler)

  - Directory of gene lists used (/prepared_gene_lists or custom)

  - Directory of mapped gene lists used (/mapped_gene_lists)

.. Important::

   Input files must be placed in the `/data` directory.

   Gene list filenames **must** follow a consistent `timepoint1-timepoint2-direction` pattern 
   (e.g., `C-d1-up`, `d1-d3-down`) - See :ref:`example <exp>` down below.

   The same naming convention applies to mapped gene lists.

**Outputs:**

Running this module produces both tabular reports and visual summaries
for each enriched term, along with a centralized plots directory.

- **Per-term directories** (named after the enriched term):

  - **Counts report** (counts.<TermID>) – contains enriched term
    metadata (*TermID, Name, Source, Term_size*) and the number of genes
    from the lists involved at each timepoint.

  - **Gene members report** (members.<TermID>) – lists the gene names
    from the differential lists contributing to the term at each
    timepoint.

  - **Binary matrix** – a presence/absence (1/0) matrix showing which
    genes appear in the term across timepoints.

  - **Heatmap** – visualization of the binary matrix, highlighting up-
    and down-regulated gene presence across the time series.

  - **Line chart** – plots the number of associated genes per timepoint,
    with separate curves for up- and down-regulated genes.

- **Global outputs:**

  - A directory named “0_plots”, which aggregates all visual plots
    (heatmaps and line charts) for quick inspection across all enriched
    terms.

.. Note::

  For more details, see the :ref:`Module 8 Outputs <out8>` section.

**Variables defined in the config0 to control execution of Module 8**

.. table::
  :align: left
  :widths: auto
    
  +-----------------+-------------------------------------------+-------------+
  | Variables       | Description                               | Example     |
  +=================+===========================================+=============+
  | dir             | Target directory name containing the gene | 'standard'  |
  |                 | lists. The directory must be in /data.    |             |
  |                 | Possible to also use “standard” as a      |             |
  |                 | value and it falls to the                 |             |
  |                 | “preparaed_gene_lists” directory if it    |             |
  |                 | exists in /data.                          |             |
  +-----------------+-------------------------------------------+-------------+
  | order           | Define the time points order. Time points | 'C d1 d3    |
  |                 | must be specified in the gene lists files | 1w'         |
  |                 | names saved in the assigned “dir”         |             |
  |                 | parameter.                                |             |
  +-----------------+-------------------------------------------+-------------+
  | field_separator | Indicate the field separator of the gene  | '-'         |
  |                 | lists file names.                         |             |
  +-----------------+-------------------------------------------+-------------+
  | method          | Directory with the enrichment results to  | 'panther'   |
  |                 | build the plots.                          |             |
  |                 |                                           | 'gprofiler' |
  +-----------------+-------------------------------------------+-------------+


.. _exp:

**Example:**

Suppose you have the following **gene list files** in /data/prepared_gene_lists directory:

- C-d1-up, C-d1-down, d1-d3-up, d1-d3-down, d3-1w-down, d3-1w-up,
  1w-3w-up and 1w-3w-down.

And define the parameters in config0 as:

.. code-block:: ini

  method='panther'
  dir='standard'
  order='C d1 d3 1w'
  field_separator='-'

**What happens:**

1. The module reads enrichment results from the panther results
   directory.

2. Parses the filenames to match comparisons (e.g., C-d1-up
   corresponds to “control vs day 1, up-regulated genes”, 1w-3w-down
   corresponds to “1 week vs 3 week, down-regulated genes”).

3. Counts how many genes from each differential list are annotated in
   each enriched term at each timepoint.

4. Results are aggregated across timepoints for plotting.

**Visual outputs generated:**

- **Heatmap**: Rows represent enriched terms (e.g., *apoptotic process*,
  *T-cell activation*). Columns represent ordered timepoints (C, d1, d3,
  1w). Cell colors show whether up- (blue) or down- (red) regulated
  genes contribute to that term at each stage.

- **Line chart**: For each enriched term, two lines are drawn:

  - Orange = number of up-regulated genes associated with the term.

  - Blue = number of down-regulated genes associated with the term.
    This reveals trends like “apoptotic process increases in
    up-regulation between C → d1 but decreases after 1w.”

.. important::

  - Gene list filenames **must contain timepoint identifiers** consistent
    with the order parameter.
