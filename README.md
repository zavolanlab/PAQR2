[![ci](https://github.com/zavolanlab/tandem-pas/workflows/CI/badge.svg?branch=main)](https://github.com/zavolanlab/tandem-pas/actions?query=workflow%3ACI)
[![GitHub issues](https://img.shields.io/github/issues/zavolanlab/PAQR2)](https://github.com/zavolanlab/PAQR2/issues)
[![GitHub license](https://img.shields.io/github/license/zavolanlab/PAQR2)](https://github.com/zavolanlab/PAQR2/blob/main/LICENSE)

# PAQR

PAQR is a tool (implemented as snakemake workflow) that allows the quantification of transcript 3' ends (or poly(A) sites) based on standard RNA-seq data. As input it requires alignment files in BAM format (along with their corresponding ".bai" indices) and a bed file with coordinates of known "tandem" poly(A) sites (i.e. poly(A) sites that belong to the same gene). It returns a table of quantified tandem poly(A) sites.

For more information, please refer to the original [PAQR publication][paqr-pub].   
The repository mentioned in the publication is accessible [here][paqr-old]. Please be aware that that repository is no longer maintained, and the repository you're currently looking at contains the most up-to-date version of PAQR.

> Compatible input data:   
> By default paired-end sequencing with read1 - reverse orientation, read2 - forward orientation is assumed. If your data is unstranded, you'll have to specify this in the `config.yaml`.   
> Single-stranded data with the reads in sense direction are processed properly too, but PAQR does not support single-end data in reverse orientation.


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
on your system$^*$. You may have to ask an authorized person (e.g., a systems
administrator) to do that. This will almost certainly be required if you want to run the workflow on a high-performance computing (HPC) cluster. 

After installing Singularity, or should you choose not to use containerization but only conda environments, install the remaining dependencies with:
```bash
conda env create -f install/environment.yml
```

$^*$If you have a Linux machine, as well as root privileges, (e.g., if you plan to run the workflow on your own computer), you can execute the following command to include Singularity in the Conda environment instead:
```bash
conda env create -f install/environment.root.yml
```

### 4. Activate environment

Activate the Conda environment with:

```bash
conda activate paqr2
```

## Preparations

### 1. Create tandem poly(A) sites file
For poly(A) site quantification and calculation of UTR length changes, PAQR requires a reference of known "tandem" poly(A) sites in bed format with additional columns. This file can be conveniently created with the [tandem PAS pipeline][tpas-repo], which uses the [PolyASite atlas][polyasite-atlas] as a global reference of poly(A) sites. Only poly(A) sites on terminal exons, not overlapping with exons of other transcripts are selected. Different files for stranded and unstranded RNA-seq data analysis can be created. The columns of the tandem PAS file are as follows:

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
For PAQR to work correctly, it is crucial that the input RNA-seq samples are of good quality. We therefore strongly advise you to run a [TIN-score calculation][tin-repo] on your samples before using them in PAQR. As a rule of thumb, the Median TIN score across all transcripts in a sample should be at least 70 in order for PAQR to give reliable results.

### 3. Configure the input parameters
The file `configs/config.yaml` contains all information about used parameter values, data locations, file names and so on. During a run, all steps of the PAQR pipeline will retrieve their paramter values from this file. It follows the yaml syntax (find more information about yaml and it's syntax [here](http://www.yaml.org/)) making it easy to read and edit. The main principles are:
  - everything that comes after a `#` symbol is considered as comment and will not be interpreted
  - paramters are given as key-value pair, with `key` being the name and `value` the value of any paramter


Some entries require your editing while most of them you can leave unchanged. The comments should give you the information about the meaning of the individual parameters. If you need to change path names please ensure to **use relative instead of absolute path names**.

### 4. Prepare a "samples.tsv"
This file will contain the names (column header "ID"), conditions (header "condition") and paths (relative to the execution directory)(header "bam") to all your input bam files. For an example see [configs/samples.tsv][sample-tsv]
> NOTE: PAQR requires `.bam` AND corresponding `.bam.bai` files to be placed alongside in the same directory. It also expects the basenames of the two files to be the same. Thus, only .bam filepaths have to be given in the samples table, and the corresponding .bai filepath is inferred from there.


## Execution
Create a new directory for your analysis within this directory and cd into it. Make sure you have the conda environment `paqr2` activated. For your convenience, the directory `execute` contains bash scripts that can be used to start local and slurm runs, using either singularity or conda.

For example, you could run the example config `configs/config.yml` locally with singularity with:

```bash
bash snakemake_local_run_singularity_containers.sh configs/config.yml
```

### Pipeline steps
![rule_graph][rule-graph]

[rule-graph]: images/rulegraph.svg

### Outputs
For each sample separately:
- wiggle files of read coverages
- UTR extensions made if known PAS downstream of annotated exon
All samples represented in one table:
- tables of tandem PAS positions (tsv; columns: coordinate, relative position within terminal exon)
- table of PAS relative usage (tsv; columns: chromosome, start, end, PAS ID, score, strand, PAS index on current exon, number of PAS on current exon, exon, gene, relative usage for each sample)
- table of tandem PAS expression (tsv; columns same as above, tpm instead of relative usage)
- table of "singular" PAS, where PAQR could not detect any usage of the PAS's tandem "siblings" (tsv; columns same as above)
- table of weithed average exon lengths (tsv; columns: exon, relative exon length for each sample)
- CDF plot of weighted average exon lengths (pdf)

### Testing the execution
This repository contains a small test dataset included for the users to test their installation of PAQR. In order to initiate the test run (with conda environments technology) please navigate to the root of the cloned repository (make sure you have the conda environment `paqr2` activated) and execute the following command:
```bash
bash execute/snakemake_local_run_conda_environments.sh ../tests/integration/input/config.yml && rm -rf output
```

## About
If you're using PAQR in your research, please cite   
Gruber, A.J., Schmidt, R., Ghosh, S. *et al.* Discovery of physiological and cancer-related regulators of 3′ UTR processing with KAPAC. *Genome Biol* **19**, 44 (2018). [https://doi.org/10.1186/s13059-018-1415-3][paqr-pub]


[polyasite-atlas]: <https://polyasite.unibas.ch/atlas>
[tpas-repo]: <https://github.com/zavolanlab/tandem-pas>
[tin-repo]: <https://github.com/zavolanlab/tin-score-calculation>
[conda]: <https://docs.conda.io/projects/conda/en/latest/index.html>
[miniconda-installation]: <https://docs.conda.io/en/latest/miniconda.html>
[rule-graph]: images/dag.svg
[snakemake]: <https://snakemake.readthedocs.io/en/stable/>
[singularity]: <https://sylabs.io/singularity/>
[singularity-install]: <https://sylabs.io/guides/3.8/user-guide/quick_start.html>
[slurm]: <https://slurm.schedmd.com/documentation.html>
[ensembl]: <https://www.ensembl.org/index.html>
[paqr-old]: <https://github.com/zavolanlab/PAQR_KAPAC>
[paqr-pub]: <https://doi.org/10.1186/s13059-018-1415-3>
[sample-tsv]: configs/samples.tsv