#!/usr/bin/env bash

# Run the pipeline on a local machine
# with conda environments
# Usage: bash snakemake_local_run_conda_environments.sh ../configs/config.yaml

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
    --use-conda \
    --cores=2 \
    --printshellcmds \
    --verbose
