**Test data**
=====================

**Test 1 – Running Enrichment Analysis with Expression Dataset**
-------------------------------------------------------------------

This test demonstrates how auto-Enrich can be run with all modules
(expect Module 8) and flags. The input includes an expression matrix 
from *Mus musculus*, the necessary configuration files and a gene set
file from the `Mouse Collections of
MSigDB <https://www.gsea-msigdb.org/gsea/msigdb/mouse/collections.jsp>`_.

The test files are provided in test1.zip:

- `test1.zip <inserir_evo6_url>_` **INSERIR URL** 

**Contents inside the inputs directory of test1.zip**:

- **config0**: Pipeline configuration file, setup to run input
  preparation (Modules 1,2 and 5), enrichment analysis (Modules 3, 4 and
  6) on pre-selected sources, and filtering (Module 7)

- **config1**: Configuration file to coordinate Module 1, to extract
  differentially expressed genes (in this test genes fold change > 1,
  up-regulated) from the selected data samples

- **config5**: Configuration file to coordinate Module 5, to transform
  the input expression matrix into the expression dataset (.gct) and
  phenotype labels (.cls) to run GSEA classic

- **expression_matrix.tsv**: Gene expression data matrix (Gene ID and
  gene expression samples data)

- **gsea_parameters**: GSEA run settings

- **m2.all.v2024.Mm.entrez.gmt**: Gene Set file (GMX) containing the
  gene sets to run GSEA

**Workflow (tools=”1,2,3,4,5,6,7”):**

1. The expression data is preprocessed (Module 1), building a gene list
of ove-expressed genes

2. Gene Identifiers list is mapped (Module 2)

3. Over-Representation Enrichment Analysis is run using g:Profiler
   (Module 3)

4. Over-Representation Enrichment Analysis is run using PANTHER (Module
   4)

5. Input files, expression_dataset.gct and phenotype_labels.cls, for
   GSEA are created (Module 5), following the module configuration file,
   config5

6. Gene Set Enrichment Analysis (GSEA) is executed using the prepared
   inputs and gsea_parameters (Module 6)

7. The annotation’s results from the enrichment analysis tools are
   filtered (Module 7)

8. The additional flags of reactome hierarchy three build and gene
   occurrences file act over the enrichment results

**Outputs directories after the run:**

- **/prepared_gene_lists** → gene list prepared by **Module 1**.

- **/mapped_gene_lists** → mapped gene identifier list by **Module 2**.

- **/gprofiler** → enrichment results from **Module 3** (g:Profiler
  plus).

- **/panther** → enrichment results from **Module 4** (PANTHER plus).

- **/gsea** → input and analysis outputs from **Modules 5 and 6**

- **/annotations** → consolidated mapping and term annotation files from
  Modules 2–4, enabling easy cross-referencing of enriched terms and
  gene memberships.

**Test 2 – Running Enrichment Analysis Multiple Gene Lists**
---------------------------------------------------------------

This test demonstrates how auto-Enrich can be run to perform
**g:Profiler and PANTHER Over-Representation analysis** using
one or more pre-prepared gene ID lists.

- A **single gene list** can be run by specifying its name in the ``gene_list``
  variable in config0.

- **Multiple gene lists** can be run together by placing all the desired
  gene lists in a directory named ``/prepared_gene_lists`` within your data directory (/data).

In this test, **four gene ID lists** are included, all from *Mus
musculus*. 

The test files are provided in test2.zip:

- `test2.zip <inserir_evo6_url>_` **INSERIR URL** 

**Contents inside the inputs directory of test2.zip:**

- **config0**: Pipeline configuration file, setup to map input gene IDs
  (Module 2) and run over-representation analysis (Modules 3 and 4)

- **/prepared_gene_lists**: Contains the input gene ID lists.

**Workflow (tools=”2,3,4”):**

1. All Gene IDs lists inside /prepared_gene_lists are mapped (Module 2)

2. Over-Representation Enrichment Analysis of all mapped Gene IDs lists
   are run using g:Profiler (Module 3)

3. Over-Representation Enrichment Analysis of all mapped Gene IDs lists
   are run using PANTHER (Module 4)

**Output directories after the run:**

- **/mapped_gene_lists** → mapped gene identifier list by **Module 2**.

- **/gprofiler** → enrichment results from **Module 3** (g:Profiler
  plus).

- **/panther** → enrichment results from **Module 4** (PANTHER plus).

- **/annotations** → consolidated mapping and term annotation files from
  Modules 2–4, enabling easy cross-referencing of enriched terms and
  gene memberships.

After running Over-Representation analysis with multiple gene lists, results are organized by **tool** and **gene list**:

- /gprofiler/

  - /gprofiler/gene_list1/results/ – Enrichment results for ``gene_list1`` using ``g:Profiler``  
  - /gprofiler/gene_list2/results/ – Enrichment results for ``gene_list2`` using ``g:Profiler``  

- /panther/

  - /panther/gene_list1/results/ – Enrichment results for ``gene_list1`` using ``PANTHER``  
  - /panther/gene_list2/results/ – Enrichment results for ``gene_list2`` using ``PANTHER``  

Each **results** directory contains:

- **Short and long result tables**: ``short_results.tsv`` and ``long_results.tsv``  

- **Term annotation files**: ``terms_annotations_results.tsv``  

- **Subdirectories** for each source, containing respective results files, and enriched
  terms annotations.

**Test 3 – Preparing and Running GSEA Preranked**
----------------------------------------------------

This test demonstrates how auto-Enrich can be used prepare GSEA
Preranked inputs from an expression matrix and run GSEA. The input
includes an expression matrix with pre-calculated averages from *Mus
musculus* gene IDs, the necessary configuration files and a gene set
file from the `Mouse Collections of
MSigDB <https://www.gsea-msigdb.org/gsea/msigdb/mouse/collections.jsp>`__.
In this test two Preranked gene lists are generated, and two runs of
GSEA are performed. 

The test files are provided in test3.zip:

- `test3.zip <inserir_evo6_url>_` **INSERIR URL** 

**Contents inside the inputs directory of test3.zip:**

- **config0**: Pipeline configuration file, set up to run preparation of
  pre-ranked gene lists (Module 5) and GSEA Preranked run (Module 6)

- **config5**: Configuration file to coordinate Module 5, to transform
  the input expression matrix TWO pre-ranked genes lists (.rnk)

- **expression_matrix.tsv**: Gene expression data matrix (Gene ID and
  gene expression averages data)

- **gsea_parameters**: GSEA run settings

- **m2.all.v2024.Mm.entrez.gmt**: Gene Set file (GMT) containing the
  gene sets to run GSEA

**Workflow (tools=”5,6”):**

1. Two preranked gene lists (RNK) for GSEA are generated (**Module 5**),
   following the module configuration file (**config5**).

2. Gene Set Enrichment Analysis (**GSEA**) is executed using the prepared
   inputs and **gsea_parameters** (**Module 6**).

**Output directory after the run:**

- **/gsea**: GSEA inputs and results

The results of the GSEA input preparation and run, are stored inside the **gsea** 
directory, which contains:

- **/preranked_gene_lists**: Contains the preranked gene lists generated
  by Module 5

- **/results**: Stores the GSEA results of both runs of the two
  preranked gene lists in separate directories

  - /m2.all.logFC_M_naive_A_naive.GseaPreranked

  - /m2.all.logFC_M_SCI_A_SCI.GseaPreranked

- **gsea_parameters** files: The GSEA settings files used in the runs

- **m2.all.v2024.Mm.entrez.gmt**: Gene Set file (GMT) containing the
  gene sets to run GSEA

Each **results** directory contains:

- **Short and long result tables**: ``short_results.tsv`` and ``long_results.tsv``  

- **Term annotation files**: ``terms_annotations_results.tsv``  

- **Subdirectories** for each source, containing respective results files, and enriched
  terms annotations.
