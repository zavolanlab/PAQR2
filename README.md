# PAQR

PAQR is a tool that allows the quantification of transcript 3' ends (or poly(A) sites) based on standard RNA-seq data. As input it requires alignment files in BAM format and a bed file with coordinates of known "tandem" poly(A) sites (i.e. poly(A) sites that belong to the same gene). It returns a table of quantified tandem poly(A) sites.

## Installation 
### 1. Clone the repository

Go to the desired directory/folder on your file system, then clone/get the 
repository and move into the respective directory with:

```bash
git clone git@github.com:zavolanlab/PAQR2.git
cd PAQR2
```

### 2. Conda installation

Workflow dependencies can be conveniently installed with the [Conda][conda]
package manager. We recommend that you install [Miniconda][miniconda-installation] 
for your system (Linux). Be sure to select Python 3 option. 

### 3. Dependencies installation

For improved reproducibility and reusability of the workflow,
each individual step of the workflow runs either in its own [Singularity][singularity]
container OR in its own [Conda][conda] virtual environemnt. 
As a consequence, running this workflow has very few individual dependencies. 
If you want to make use of **container execution**, please [install
Singularity][singularity-install] in privileged mode, depending
on your system. You may have to ask an authorized person (e.g., a systems
administrator) to do that. This will almost certainly be required if you want to run the workflow on a high-performance computing (HPC) cluster. 

After installing Singularity, or should you choose not to use containerization but only conda environments, install the remaining dependencies with:
```bash
conda env create -f environment.yml
```

### 4. Activate environment

Activate the Conda environment with:

```bash
conda activate paqr2
```

## Preparations

### 1. Create tandem poly(A) sites file
For poly(A) site quantification and calculation of UTR length changes, PAQR requires a reference of known "tandem" poly(A) sites in bed format with additional columns. This file can be conveniently created with the [tandem PAS pipeline][tpas_repo], which uses the [PolyASite atlas][polyasite-atlas] as a global reference of poly(A) sites. Only poly(A) sites on terminal exons, not overlapping with exons of other transcripts are selected. The columns of the tandem PAS file are as follows:

| Column | Value | Comments |
| --- | --- | --- |
| 1 | chromosome | Ensembl naming scheme (no leading "chr") |
| 2 | start | start of poly(A) site cluster (or single site) |
| 3 | end | end of poly(A) site cluster (or single site) |
| 4 | ID | identifier in the format "chr:site:strand", where site is the representative site of the cluster (or the single nucleotide position of the single site) |
| 5 | score | e.g. tpm |
| 6 | strand | + or - |
| 7 | PAS rank | rank of the poly(A) site among its siblings in current transcript relative to 5' end | 
| 8 | number of tandem PAS | total number of poly(A) sites present in transcript |
| 9 | exon info | in the format "transcript_ID:total_exons:current_exon:start:stop". Ensembl transcript ID, the number of exons belonging to that transcript, the rank of the considered exon (equals the number of exons if only terminal exons are considered), start and stop coordinates of the exon |
| 10 | gene ID | Ensembl gene ID |


### 2. Ensure sufficient quality of your input samples
For PAQR to work correctly, it is crucial that the input RNA-seq samples are of good quality. We therefore strongly advise you to run a [TIN-score calculation][tin-repo] on your samples before using them in PAQR. As a rule of thumb, samples shoul have a TIN-score of at least 70 in order for PAQR to give reliable results.

### 3. Configure the input parameters
The file `configs/config.yaml` contains all information about used parameter values, data locations, file names and so on. During a run, all steps of the PAQR pipeline will retrieve their paramter values from this file. It follows the yaml syntax (find more information about yaml and it's syntax [here](http://www.yaml.org/)) making it easy to read and edit. The main principles are:
  - everything that comes after a `#` symbol is considered as comment and will not be interpreted
  - paramters are given as key-value pair, with `key` being the name and `value` the value of any paramter


Some entries require your editing while most of them you can leave unchanged. The comments should give you the information about the meaning of the individual parameters. If you need to change path names please ensure to **use relative instead of absolute path names**.



## Execution
Create a new directory for your analysis within this directory and cd into it. Make sure you have the conda environment `paqr2` activated. For your convenience, the directory `execution` contains bash scripts that can be used to start local and slurm runs, using either singularity or conda. In order for the latter to work, you will have to specify the partition to be used in the respective bash scripts at `-p [PARTITION]`.

### Pipeline steps
![rule_graph][rule-graph]

[rule-graph]: images/rulegraph.svg




[polyasite-atlas]: <https://polyasite.unibas.ch/atlas>
[tpas-repo]: <https://github.com/zavolanlab/tandem-pas>
[tin-repo]: <https://github.com/zavolanlab/tin-score-calculation>
[conda]: <https://docs.conda.io/projects/conda/en/latest/index.html>
[miniconda-installation]: <https://docs.conda.io/en/latest/miniconda.html>
[rule-graph]: images/dag.svg
[snakemake]: <https://snakemake.readthedocs.io/en/stable/>
[singularity]: <https://sylabs.io/singularity/>
[singularity-install]: <https://sylabs.io/guides/3.5/admin-guide/installation.html>
[slurm]: <https://slurm.schedmd.com/documentation.html>
[ensembl]: <https://www.ensembl.org/index.html>
[paqr]: <https://github.com/zavolanlab/PAQR_KAPAC>