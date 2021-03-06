#!/usr/bin/env bash

# Run the pipeline on a computational cluster
# with conda virtual environments
# Usage: bash snakemake_cluster_run_conda_environments.sh ../configs/config.yaml

cleanup () {
    rc=$?
    # rm -rf .snakemake/
    # rm -rf ../output/
    cd "$user_dir"
    echo "Exit status: $rc"
}
trap cleanup SIGINT

set -eo pipefail  # ensures that script exits at first command that exits with non-zero status
set -u  # ensures that script exits when unset variables are used
set -x  # facilitates debugging by printing out executed commands

user_dir=$PWD
pipeline_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$pipeline_dir"

snakemake \
    --snakefile="../Snakefile" \
    --configfile=$1 \
    --cluster-config="../configs/cluster_config.json" \
    --jobscript="../configs/jobscript.sh" \
    --use-conda \
    --cores 128 \
    --local-cores 2 \
    --printshellcmds \
    --verbose \
    --cluster \
    "sbatch \
    --cpus-per-task={cluster.threads} \
    --mem={cluster.mem} \
    --qos={cluster.queue} \
    --time={cluster.time} \
    --output={params.LOG_cluster_log}-%j-%N.log"
