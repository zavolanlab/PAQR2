##############################################################################
#
#   Snakemake pipeline: PAQR
#   based on: https://github.com/zavolanlab/PAQR_KAPAC
#
#   AUTHOR: Maciej_Bak, Ralf_Schmidt, CJ Herrmann
#   AFFILIATION: University_of_Basel
#   AFFILIATION: Swiss_Institute_of_Bioinformatics
#   CONTACT: maciej.bak@unibas.ch
#   CREATED: 05-04-2020
#   LICENSE: Apache_2.0
#
##############################################################################

# imports
import sys
import os
import traceback
import pandas as pd

# local rules
localrules: PAQ_all, PAQ_create_outdir

samples = pd.read_table(config['PAQ_samples_table'], index_col=0, comment='#')

##############################################################################
### Target rule with final output of the pipeline
##############################################################################

rule PAQ_all:
    """
    Gathering all output
    """
    input:
        TSV_filtered_expression = expand(
            os.path.join(
                "{PAQ_output_dir}",
                "filtered_pas_expression.tsv"
            ),
            PAQ_output_dir = config["PAQ_outdir"]
        ),
        TSV_filtered_pas_positions = expand(
            os.path.join(
                "{PAQ_output_dir}",
                "filtered_pas_positions.tsv"
            ),
            PAQ_output_dir = config["PAQ_outdir"]
        ),
        PDF_exon_lengths = expand(
            os.path.join(
                "{PAQ_output_dir}",
                "weighted_avg_exon_lengths.pdf"
            ),
            PAQ_output_dir = config["PAQ_outdir"]
        )

##############################################################################
### Create directories for the results
##############################################################################

rule PAQ_create_outdir:
    """
    Preparing directories for the results
    """
    output:
        TEMP_ = temp(
            os.path.join(
                "{PAQ_output_dir}",
                "PAQ_outdir"
            )
        )

    params:
        DIR_output_dir = "{PAQ_output_dir}",
        LOG_cluster_log = os.path.join(
            "{PAQ_output_dir}",
            "cluster_log"
        ),
        LOG_local_log = os.path.join(
            "{PAQ_output_dir}",
            "local_log"
        )

    conda:
        "env/bash.yml"

    singularity:
        "docker://bash:4.4.18"

    shell:
        """
        mkdir -p {params.DIR_output_dir}; \
        mkdir -p {params.LOG_cluster_log}; \
        mkdir -p {params.LOG_local_log}; \
        touch {output.TEMP_}
        """

##############################################################################
### Create Poly-A site coverages
##############################################################################

rule PAQ_create_coverages:
    """
    Extracting the coverages of poly(A) sites from the alignment
    """
    input:
        TEMP_ = os.path.join(
            "{PAQ_output_dir}",
            "PAQ_outdir"
        ),
        BAM_alignment = lambda wildcards:
                os.path.join(config["PAQ_indir"],
                samples.loc[wildcards.sample_ID,"bam"]),
        BAI_alignment_index = lambda wildcards:
                os.path.join(config["PAQ_indir"],
                samples.loc[wildcards.sample_ID,"bai"]),
        BED_pas = config['PAQ_tandem_pas'],
        SCRIPT_ = os.path.join(
            config["PAQ_scripts_dir"],
            "create-pas-coverages.py"
        )

    output:
        PKL_pas_coverage = os.path.join(
            "{PAQ_output_dir}",
            "pas_coverages",
            "{sample_ID}.pkl"
        ),
        TSV_extensions = os.path.join(
            "{PAQ_output_dir}",
            "pas_coverages",
            "{sample_ID}.extensions.tsv"
        )

    params:
        INT_coverage_downstream_extension = config['PAQ_coverage_downstream_extension'],
        INT_min_distance_start_to_proximal = config['PAQ_min_distance_start_to_proximal'],
        STR_unstranded_flag = lambda wildcards:
            "--unstranded" if config['PAQ_coverage_unstranded'] == "yes" else "",
        LOG_cluster_log = os.path.join(
            "{PAQ_output_dir}",
            "cluster_log",
            "PAQ_create_coverages.{sample_ID}.log"
        ),
        INT_processes = 8

    log:
        LOG_local_stdout = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_create_coverages.{sample_ID}.stdout.log"
        ),
        LOG_local_stderr = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_create_coverages.{sample_ID}.stderr.log"
        )

    benchmark:
        os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_create_coverages.{sample_ID}.benchmark.log"
        )

    conda:
        "env/python.yml"

    singularity:
        "docker://zavolab/mapp_base_python:1.1.1"

    shell:
        """
        python {input.SCRIPT_} \
        --bam {input.BAM_alignment} \
        --cluster {input.BED_pas} \
        --ds_extension {params.INT_coverage_downstream_extension} \
        --min_dist_exStart2prox {params.INT_min_distance_start_to_proximal} \
        --processors {params.INT_processes} \
        --pickle_out {output.PKL_pas_coverage} \
        {params.STR_unstranded_flag} \
        1> {log.LOG_local_stdout} 2> {log.LOG_local_stderr}
        """

##############################################################################
### Infer relative usage of poly(A) sites
##############################################################################

rule PAQ_infer_relative_usage:
    """
    Infer used poly(A) sites based on the coverage profiles
    and determine relative usage of those.
    """
    input:
        BED_pas = config['PAQ_tandem_pas'],
        PKL_pas_coverage = expand(
            os.path.join(
                "{PAQ_output_dir}",
                "pas_coverages",
                "{sample_ID}.pkl"
            ),
            PAQ_output_dir = config["PAQ_outdir"],
            sample_ID = samples.index
        ),
        TSV_extensions = expand(
            os.path.join(
                "{PAQ_output_dir}",
                "pas_coverages",
                "{sample_ID}.extensions.tsv"
            ),
            PAQ_output_dir = config["PAQ_outdir"],
            sample_ID = samples.index
        ),
        SCRIPT_ = os.path.join(
            config["PAQ_scripts_dir"],
            "infer-pas-expression.py"
        )

    output:
        TSV_pas_relative_usages = os.path.join(
            "{PAQ_output_dir}",
            "tandem_pas_relative_usage.tsv"
        ),
        TSV_pas_epxression_values = os.path.join(
            "{PAQ_output_dir}",
            "tandem_pas_expression.tsv"
        ),
        TSV_distal_sites = os.path.join(
            "{PAQ_output_dir}",
            "singular_pas_expression.tsv"
        )

    params:
        LIST_sample_conditions = samples["condition"].tolist(),
        LIST_sample_names = samples.index.tolist(),
        INT_read_length = config['PAQ_read_length'],
        INT_min_length_mean_coverage = config['PAQ_min_length_mean_coverage'],
        FLOAT_min_mean_exon_coverage = config['PAQ_min_mean_exon_coverage'],
        INT_distal_downstream_extension = config['PAQ_distal_downstream_extension'],
        FLOAT_max_mean_coverage = config['PAQ_max_mean_coverage'],
        FLOAT_cluster_distance = config['PAQ_cluster_distance'],
        INT_upstream_cluster_extension = config['PAQ_upstream_cluster_extension'],
        FLOAT_coverage_mse_ratio_limit = config['PAQ_coverage_mse_ratio_limit'],
        LOG_cluster_log = os.path.join(
            "{PAQ_output_dir}",
            "cluster_log",
            "PAQ_infer_relative_usage.log"
        ),
        INT_processes = 8

    log:
        LOG_local_stdout = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_infer_relative_usage.stdout.log"
        ),
        LOG_local_stderr = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_infer_relative_usage.stderr.log"
        )

    benchmark:
        os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_infer_relative_usage.benchmark.log"
        )

    conda:
        "env/python.yml"

    singularity:
        "docker://zavolab/mapp_base_python:1.1.1"

    shell:
        """
        python {input.SCRIPT_} \
        --expressions_out {output.TSV_pas_epxression_values} \
        --clusters {input.BED_pas} \
        --coverages {input.PKL_pas_coverage} \
        --conditions {params.LIST_sample_conditions} \
        --names {params.LIST_sample_names} \
        --ex_extension_files {input.TSV_extensions} \
        --read_length {params.INT_read_length} \
        --min_coverage_region {params.INT_min_length_mean_coverage} \
        --min_mean_coverage {params.FLOAT_min_mean_exon_coverage} \
        --ds_reg_for_no_coverage {params.INT_distal_downstream_extension} \
        --min_cluster_distance {params.FLOAT_cluster_distance} \
        --mse_ratio_threshold {params.FLOAT_coverage_mse_ratio_limit} \
        --best_break_point_upstream_extension {params.INT_upstream_cluster_extension} \
        --max_downstream_coverage {params.FLOAT_max_mean_coverage} \
        --distal_sites {output.TSV_distal_sites} \
        --processors {params.INT_processes} \
        1> {output.TSV_pas_relative_usages} \
        2> {log.LOG_local_stderr}
        """

##############################################################################
### Obtain relative positions of poly(A) sites
##############################################################################

rule PAQ_relative_pas_positions:
    """
    Obtain relative positions of the poly(A) sites within the terminal exons
    """
    input:
        TSV_pas_epxression_values = os.path.join(
            "{PAQ_output_dir}",
            "tandem_pas_expression.tsv"
        ),
        SCRIPT_ = os.path.join(
            config["PAQ_scripts_dir"],
            "relative-pas-position-within-exon.py"
        )

    output:
        TSV_relative_pas_positions = os.path.join(
            "{PAQ_output_dir}",
            "relative_pas_positions.tsv"
        )

    params:
        LOG_cluster_log = os.path.join(
            "{PAQ_output_dir}",
            "cluster_log",
            "PAQ_relative_pas_positions.log"
        )

    log:
        LOG_local_stdout = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_relative_pas_positions.stdout.log"
        ),
        LOG_local_stderr = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_relative_pas_positions.stderr.log"
        )

    benchmark:
        os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_relative_pas_positions.benchmark.log"
        )

    conda:
        "env/python.yml"

    singularity:
        "docker://zavolab/mapp_base_python:1.1.1"

    shell:
        """
        python {input.SCRIPT_} \
        --infile {input.TSV_pas_epxression_values} \
        1> {output.TSV_relative_pas_positions} \
        2> {log.LOG_local_stderr}
        """

##############################################################################
###  Normalize expression
##############################################################################

rule PAQ_normalize_expression:
    """
    TPM normalize the expression values by the number of mapped reads
    """
    input:
        TSV_pas_epxression_values = os.path.join(
            "{PAQ_output_dir}",
            "tandem_pas_expression.tsv"
        ),
        TSV_distal_sites = os.path.join(
            "{PAQ_output_dir}",
            "singular_pas_expression.tsv"
        ),
        SCRIPT_ = os.path.join(
            config["PAQ_scripts_dir"],
            "normalize-pas-expression.py"
        )

    output:
        TSV_normalized_expression = os.path.join(
            "{PAQ_output_dir}",
            "tandem_pas_expression_normalized.tsv"
        )

    params:
        LOG_cluster_log = os.path.join(
            "{PAQ_output_dir}",
            "cluster_log",
            "PAQ_normalize_expression.log"
        )

    log:
        LOG_local_stdout = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_normalize_expression.stdout.log"
        ),
        LOG_local_stderr = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_normalize_expression.stderr.log"
        )

    benchmark:
        os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_normalize_expression.benchmark.log"
        )

    conda:
        "env/python.yml"

    singularity:
        "docker://zavolab/mapp_base_python:1.1.1"

    shell:
        """
        python {input.SCRIPT_} \
        --tandem-pas-expression {input.TSV_pas_epxression_values} \
        --distal-pas-expression {input.TSV_distal_sites} \
        --normalized-tandem-pas-expression {output.TSV_normalized_expression} \
        1> {log.LOG_local_stdout} 2> {log.LOG_local_stderr}
        """

##############################################################################
###  Filter pas based on expression
##############################################################################

rule PAQ_filter_on_expression:
    """
    Filter summary table: remove all exons for which any site had
    zero expression in all samples; keep tandem pas per terminal exon
    """
    input:
        TSV_normalized_expression = os.path.join(
            "{PAQ_output_dir}",
            "tandem_pas_expression_normalized.tsv"
        ),
        TSV_relative_pas_positions = os.path.join(
            "{PAQ_output_dir}",
            "relative_pas_positions.tsv"
        ),
        TSV_relative_pas_usage = os.path.join(
            "{PAQ_output_dir}",
            "tandem_pas_relative_usage.tsv"
        ),
        SCRIPT_ = os.path.join(
            config["PAQ_scripts_dir"],
            "filter-tables.py"
        )

    output:
        TSV_filtered_expression = os.path.join(
            "{PAQ_output_dir}",
            "filtered_pas_expression.tsv"
        ),
        TSV_filtered_pas_positions = os.path.join(
            "{PAQ_output_dir}",
            "filtered_pas_positions.tsv"
        ),
        TSV_filtered_usage = os.path.join(
            "{PAQ_output_dir}",
            "filtered_pas_usage.tsv"
        )

    params:
        LOG_cluster_log = os.path.join(
            "{PAQ_output_dir}",
            "cluster_log",
            "PAQ_filter_on_expression.log"
        )

    log:
        LOG_local_stdout = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_filter_on_expression.stdout.log"
        ),
        LOG_local_stderr = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_filter_on_expression.stderr.log"
        )

    benchmark:
        os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_filter_on_expression.benchmark.log"
        )

    conda:
        "env/python.yml"

    singularity:
        "docker://zavolab/mapp_base_python:1.1.1"

    shell:
        """
        python {input.SCRIPT_} \
        --normalized-expression {input.TSV_normalized_expression} \
        --pas-positions {input.TSV_relative_pas_positions} \
        --pas-usage {input.TSV_relative_pas_usage} \
        --filtered-expression {output.TSV_filtered_expression} \
        --filtered-positions {output.TSV_filtered_pas_positions} \
        --filtered-usage {output.TSV_filtered_usage} \
        1> {log.LOG_local_stdout} 2> {log.LOG_local_stderr}
        """

#-------------------------------------------------------------------------------
# get weighted average exon length
#-------------------------------------------------------------------------------
rule PAQ_weighted_avg_exon_length:
    input:
        TSV_filtered_usage = os.path.join(
            "{PAQ_output_dir}",
            "filtered_pas_usage.tsv"
        ),
        TSV_filtered_pas_positions = os.path.join(
            "{PAQ_output_dir}",
            "filtered_pas_positions.tsv"
        ),
        SCRIPT_ = os.path.join(
            config["PAQ_scripts_dir"],
            "calculate-average-3pUTR-length.py"
        )
    output:
        TSV_exon_lengths = os.path.join(
            "{PAQ_output_dir}",
            "weighted_avg_exon_lengths.tsv"
        )
    params:
        LOG_cluster_log = os.path.join(
            "{PAQ_output_dir}",
            "cluster_log",
            "PAQ_weighted_avg_exon_length.log"
        )

    log:
        LOG_local_stdout = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_weighted_avg_exon_length.stdout.log"
        ),
        LOG_local_stderr = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_weighted_avg_exon_length.stderr.log"
        )

    benchmark:
        os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_weighted_avg_exon_length.benchmark.log"
        )

    conda:
        "env/python.yml"

    singularity:
        "docker://zavolab/mapp_base_python:1.1.1"

    shell:
        """
        python {input.SCRIPT_} \
        --relativePos={input.TSV_filtered_pas_positions} \
        --relUsage {input.TSV_filtered_usage} \
        1> {output.TSV_exon_lengths} \
        2> {log.LOG_local_stderr}
        """

#-------------------------------------------------------------------------------
# plot the cumulative distribution for the weighted average exon lengths
# per sample
#-------------------------------------------------------------------------------
rule PAQ_plot_average_exon_length:
    ##LOCAL##
    input:
        TSV_exon_lengths = os.path.join(
            "{PAQ_output_dir}",
            "weighted_avg_exon_lengths.tsv"
        ),
        SCRIPT_ = os.path.join(
            config["PAQ_scripts_dir"],
            "plot-ecdfs.R"
        )
    output:
        PDF_exon_lengths = os.path.join(
            "{PAQ_output_dir}",
            "weighted_avg_exon_lengths.pdf"
        )
    params:
        LOG_cluster_log = os.path.join(
            "{PAQ_output_dir}",
            "cluster_log",
            "PAQ_plot_average_exon_length.log"
        )

    log:
        LOG_local_stdout = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_plot_average_exon_length.stdout.log"
        ),
        LOG_local_stderr = os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_plot_average_exon_length.stderr.log"
        )

    benchmark:
        os.path.join(
            "{PAQ_output_dir}",
            "local_log",
            "PAQ_plot_average_exon_length.benchmark.log"
        )

    conda:
        "env/r.yml"

    singularity:
        "docker://zavolab/rzavolab:4.0.0"
    shell:
        '''
        Rscript {input.SCRIPT_} \
        --pdf={output.PDF_exon_lengths} \
        --file={input.TSV_exon_lengths} \
        1> {log.LOG_local_stdout} 2> {log.LOG_local_stderr}
        '''
        