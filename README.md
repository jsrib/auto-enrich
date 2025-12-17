## This image belongs to a larger project called Bioinformatics Docker Images Project (http://pegi3s.github.io/dockerfiles)

### (Please note that the original software licenses still apply)

---------------------------------------

# auto-enrich

---------------------------------------

This image facilitates the usage of auto-enrich, a pipeline for streamlined Enrichment Analysis.

## Versions

---------------------------------------

### V1.0 - October 2025

---------------------------------------

The documentation is available at `/online-manual/docs/...`
Soon to be published online...

## Using the auto-enrich image in Linux

---------------------------------------

First you need to have Docker installed in your computing environment. If you don't, follow the installation guidelines at pegi3s Bioinformatics Docker Images Project website:    [http://bdip.i3s.up.pt/](http://bdip.i3s.up.pt/getting-started#install-docker)

After pulling the required files to build the Docker Image (**auto_enrich.zip** and the **dockerfile**) you have to build the Image under the pegi3s domain using the following command:
`docker build ./ -t pegi3s/auto-enrich`

You should adpat and run the following command:
`docker run --rm -v /your/data/directory:/data pegi3s/auto-enrich`

In this command, you should replace `/your/data/directory` to point to the directory that contains the input files for the pipeline.

Please note that you must have, at least, a `config0` and `data file` (Gene Expression matrix or a Gene Identifiers list) under the `/your/data/directory` in order for the pipeline to properly work.
Detailed instructions are given in the `online_manual` (at `/online-manual/docs/...`), where the available modules, as well as parameters that must be declared for each module, are described in detail.

## Test data

---------------------------------------

In either of the following test data sets, the input files are pre-configured inside the /inputs directory. 

To run the pipeline you should adapt and run following command:
    `docker run --rm -v /your/data/directory:/data pegi3s/auto-enrich`

In this command, you should replace `/your/data/directory` to point to the directory that contains the input files for the pipeline.


### Test 1 – Running Enrichment Analysis with Expression Dataset

---------------------------------------

This test demonstrates how **auto-Enrich** can be run with all modules (except Module 8) and flags.  
The input includes an expression matrix from *Mus musculus*, the necessary configuration files, and a gene set file from the Mouse Collections of MSigDB.

**Test files:** `test1.zip`

**Contents inside the `inputs` directory of `test1.zip`**

- **config0:** Pipeline configuration file, setup to run input preparation (Modules 1, 2, and 5), enrichment analysis (Modules 3, 4, and 6) on pre-selected sources, and filtering (Module 7).  
- **config1:** Configuration file to coordinate Module 1, to extract differentially expressed genes (in this test genes with fold change > 1, up-regulated) from the selected data samples.  
- **config5:** Configuration file to coordinate Module 5, to transform the input expression matrix into the expression dataset (`.gct`) and phenotype labels (`.cls`) to run GSEA classic.  
- **expression_matrix.tsv:** Gene expression data matrix (Gene ID and gene expression samples data, from Nogueira-Rodrigues et al. (2022) https://www.researchgate.net/publication/357595784).  
- **gsea_parameters:** GSEA run settings.  
- **m2.all.v2024.Mm.entrez.gmt:** Gene Set file (GMT) containing the gene sets to run GSEA.  

**Output directories after the run:**
- /prepared_gene_lists → gene list prepared by Module 1
- /mapped_gene_lists → mapped gene identifier list by Module 2
- /gprofiler → enrichment results from Module 3 (g:Profiler plus)
- /panther → enrichment results from Module 4 (PANTHER plus)
- /gsea → input and analysis outputs from Modules 5 and 6
- /annotations → consolidated mapping and term annotation files from Modules 2–4

### Test 2 – Running Enrichment Analysis with Multiple Gene Lists

---------------------------------------

This test demonstrates how **auto-Enrich** can perform **g:Profiler** and **PANTHER** Over-Representation Analysis using one or more pre-prepared gene ID lists.

A single gene list can be run by specifying its name in the `gene_list` variable in `config0`.  
Multiple gene lists can be run together by placing all desired gene lists in a directory named `/prepared_gene_lists` within your data directory (`/data`).

In this test, four gene ID lists are included, all from *Mus musculus*.

**Test files:** `test2.zip`

**Contents inside the `inputs` directory of `test2.zip`:**

- **config0:** Pipeline configuration file, setup to map input gene IDs (Module 2) and run over-representation analysis (Modules 3 and 4).  
- **/prepared_gene_lists:** Contains the four input gene ID lists.  

**After running Over-Representation analysis with multiple gene lists, results are organized by tool and gene list:**

    /data/gprofiler/
    ├── gene_list1/results/ → Enrichment results for gene_list1 using g:Profiler
    └── gene_list2/results/ → Enrichment results for gene_list2 using g:Profiler

    /data/panther/
    ├── gene_list1/results/ → Enrichment results for gene_list1 using PANTHER
    └── gene_list2/results/ → Enrichment results for gene_list2 using PANTHER

**Each results directory contains:**

- Short and long result tables: `short_results.tsv` and `long_results.tsv`  
- Term annotation files: `terms_annotations_results.tsv`  
- Subdirectories for each source, containing respective results files and enriched term annotations.

### Test 3 – Preparing and Running GSEA Preranked

---------------------------------------

This test demonstrates how **auto-Enrich** can be used to prepare **GSEA Preranked** inputs from an expression matrix and run GSEA.  
The input includes an expression matrix with pre-calculated averages from *Mus musculus* gene IDs, the necessary configuration files, and a gene set file from the Mouse Collections of MSigDB.  
In this test, two Preranked gene lists are generated, and two runs of GSEA are performed.

**Test files:** `test3.zip`

Contents inside the `inputs` directory of `test3.zip`:

- **config0:** Pipeline configuration file, set up to run preparation of pre-ranked gene lists (Module 5) and GSEA Preranked run (Module 6).  
- **config5:** Configuration file to coordinate Module 5, to transform the input expression matrix into two pre-ranked gene lists (`.rnk`).  
- **expression_matrix.tsv:** Gene expression data matrix (Gene ID and gene expression averages data).  
- **gsea_parameters:** GSEA run settings.  
- **m2.all.v2024.Mm.entrez.gmt:** Gene Set file (GMT) containing the gene sets to run GSEA.  

**Output directory structure after the run**

    /data/gsea/
    ├── preranked_gene_lists/ → Contains the preranked gene lists generated by Module 5
    ├── results/ → Stores the GSEA results of both runs of the two preranked gene lists
    │ ├── m2.all.logFC_M_naive_A_naive.GseaPreranked/
    │ └── m2.all.logFC_M_SCI_A_SCI.GseaPreranked/
    ├── gsea_parameters → GSEA settings files used in the runs
    └── m2.all.v2024.Mm.entrez.gmt → Gene Set file (GMT) used for GSEA

**Each results directory contains:**

- Short and long result tables: `short_results.tsv` and `long_results.tsv`  
- Term annotation files: `terms_annotations_results.tsv`  
- Subdirectories for each source, containing respective results files and enriched term annotations.

## Credits

---------------------------------------

auto-enrich was developed in the context of my graduate Master’s thesis project in the University of Porto. Please cite the following when using the Pipeline:

- Ribeiro, JMS. (2025). auto-Enrich: a pipeline streamlined enrichment analysis [Master’s thesis, University of Porto]. Repositório Aberto. https://repositorio-aberto.up.pt/bitstream/10216/169254/2/738334.pdf

### Author Contributions

- J.M.S. Ribeiro¹ – Development of pipeline and thesis work

- C.P. Vieira¹,² – Supervision, conceptual support

- J. Vieira¹,² – Conceptual support, technical guidance

- H. López Fernández³,⁴ – Technical guidance

¹ Institute for Research and Innovation in Health (i3S), University of Porto, Rua Alfredo Allen 208, 4200-135 Porto, Portugal

² Institute for Molecular and Cell Biology (IBMC), Rua Alfredo Allen, 208, 4200-135 Porto, Portugal

³ Department of Computer Science, CINBIO, Universidade de Vigo, ESEI – Escuela Superior de Ingeniería Informática, 32004 Ourense, Spain

⁴ SING Research Group, Galicia Sur Health Research Institute (IIS Galicia Sur), SERGAS-UVIGO, 36213 Vigo, Spain
