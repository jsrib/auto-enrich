## This image belongs to a larger project called Bioinformatics Docker Images Project (http://pegi3s.github.io/dockerfiles)

### (Please note that the original software licenses still apply)

---------------------------------------

# auto-Enrich

---------------------------------------

This image is a modular pipeline that facilitates the usage g:Profiler, PANTHER and GSEA for streamlined Enrichment Analysis. Includes support features for input building and output processing.

## Versions

---------------------------------------

### 1.0.0 - May 2026

The documentation is available [here](http://evolution6.i3s.up.pt/auto-enrich/v1)

---------------------------------------

## Using the auto-enrich image in Linux

---------------------------------------

First you need to have Docker installed in your computing environment. If you don't, follow the installation guidelines at pegi3s Bioinformatics Docker Images Project website:    [http://bdip.i3s.up.pt/](http://bdip.i3s.up.pt/getting-started#install-docker)

To pull the docker image you should run the following command:
`docker pull pegi3s/auto-enrich`

To run an analysis you must set up the pipeline configuration file, name it `config` and have in a folder alongside one, or more, `input data file/s` (such as a Gene Expression matrix, Genes Lists, GSEA Preranked lists, Gene Sets, etc.) under the `/your/data/directory` in order for the pipeline to properly work.
Detailed instructions are given in the [documentation](http://evolution6.i3s.up.pt/auto-enrich/v1), where the available modules and parameters to be configured are described in detail.

After setting ip the require files you should adapt and run the following command:
`docker run --rm -v /your/data/directory:/data pegi3s/auto-enrich`

In this command, you should replace `/your/data/directory` to point to the folder that contains the input files for the pipeline.


## Test data
--------------------------------------

In either of the following test dataset, the input files are pre-configured inside the `/inputs` directory and the expected output inside the `/outputs` directory. 

To run the pipeline you should adapt and run following command: `docker run --rm -v /your/data/directory:/data pegi3s/auto-enrich`

In this command, you should replace `/your/data/directory` to point to the directory that contains the input files for the pipeline.


### Test 1 – Running Enrichment Analysis with Expression Dataset

---------------------------------------

This test demonstrates how the **auto-Enrich pipeline** can be run using all modules to perform Over-Representation Analysis (ORA; with g:Profiler and PANTHER) and Gene Set Enrichment Analysis (GSEA).   

The input includes a Gene Expression matrix from *Mus musculus*, the necessary configuration files, and two gene set files from the Mouse Collections of Molecular Signature DataBase ([MSigDB](https://www.gsea-msigdb.org/gsea/msigdb/mouse/collections.jsp)).

**Test files:** `test_data.zip`

**Contents inside the `inputs` directory of `test_data.zip`**:

- **expression_matrix.tsv:** Gene expression data matrix (Gene ID and respective gene expression samples data, from Nogueira-Rodrigues et al. (2022) https://www.researchgate.net/publication/357595784).
- **config:** Pipeline configuration file, setup to run input file generation for ORA and GSEA methods (Modules 1, 2, and 5), enrichment analysis (Modules 3, 4, and 6) on pre-selected sources, and output processing (Module 7).
- **/gene_sets:** Folder holding the Gene Sets from the MSigDB to be provided to the GSEA runs (includes the Reactome Pathways gene set: *m2.cp.reactome.v2026.1.Mm.symbols.gmt*; and the Gene Ontology gene set: *m5.go.v2026.1.Mm.symbols.gmt*)

**Pipeline behaviour workflow (`tools="1,2,3,4,5,6,7"`)**:

**1.** The gene expression matrix is processed to build a genes list (from column index set in the variable `gene`) of the pre-selected differentially expressed genes marked (1) at the column index (set in the variable `selected`) [Module 1]

**2.** The given input gene identifiers are mapped to GeneID, UniProtKBs, HUGO Gene Symbol and Full Name [Module 2] 

**3.** Over-Representation Enrichment Analysis are perfomed, with the mapped genes list, using g:Profiler g:GOSt tool on selected annotations-sources (set in the variable `gprofiler_dbs`), outputs are processed and enriched terms annotations are mapped [Module 3] 

**4.** Over-Representation Enrichment Analysis are perfomed, with the mapped genes list, using PANTHER Overrepresentation test on selected annotations-sources (set in the variable `panther_dbs`), outputs are processed and enriched terms annotations are mapped [Module 4] 

**5.** The gene expression matrix is partitioned into scoring Preranked Genes lists (`.rnk`) by calculating the set fold-changes (in the variables `preranked1; preranked2`) between computed experimental groups averages (set with the variables `number_groups`, `number_samples`, `samples`, `groups`, `calculate_averages`, `isoform`) [Module 5] 

**6.** Preranked Gene Set Enrichment Analysis (GSEA) are executed using the previously generated Preranked Genes lists with set paramters (`method`, `gene_set`, `nperm`, others set by default) [Module 6] 

**7.** The enrichment results from the different tools are intersected to find common results (`intersection` boolean variable) and individual tool results are filtered (by set variable `max_annot`; maximum allowed enriched term size ) [Module 7] 

**Output directories after the run:**

    # Generated inputs for Enrichment Analysis
    /data/
    ├── annotations/*                   → Utilized sources to map gene identifiers and terms annotations
    ├── preranked_gene_lists/
    │   └── selected_genes_list           → Selected genes list
    ├── mapped_gene_lists/
    │   └── selected_genes_list_map       → Mapped selected genes list
    └── gsea/
        ├── parameters_log2FC_A_SCI_A_Sham      → GSEA parameters run files (one per set run)
        └── preranked_gene_lists/               → Generated Preranked Gene lists
            ├── log2FC_A_SCI_A_Sham.rnk
            ├── log2FC_A_SCI_A_Sham.rnk
            └── log2FC_A_Sham_M_Sham.rnk

    # Enrichment Analysis results
    /data/
    ├── gprofiler/
    │   └── selected_genes_list/
    │       ├── enrichment_fields.tsv             → Enrichment results fields provided by gProfiler
    │       ├── enrichmed_terms_annotations.tsv   → Enrichmed terms annotations mapping summary
    │       └── source/annotations/*              → Raw enriched terms annotations sources
    ├── panther/
    │   └── selected_genes_list/
    │       ├── enrichment_fields.tsv             → Enrichment results fields provided by PANTHER
    │       ├── enrichmed_terms_annotations.tsv   → Enrichmed terms annotations mapping summary
    │       └── source/annotations/*              → Raw enriched terms annotations sources
    └── gsea/
        └── results/
            ├── log2FC_A_SCI_A_Sham.combined.GseaPreranked/*
            ├── log2FC_M_SCI_M_Sham.combined.GseaPreranked/*
            └── log2FC_A_Sham_M_Sham.combined.GseaPreranked/
                ├── enrichment_fields.tsv                     → Enrichment results fields provided by GSEA
                ├── enrichmed_terms_annotations.tsv           → Enrichmed terms annotations mapping summary
                ├── source/annotations/*                      → Raw enriched terms annotations sources
                └── raw_GSEA_output.zip                       → Raw GSEA output report files

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
