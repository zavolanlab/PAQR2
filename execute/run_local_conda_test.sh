# Run the pipeline on a local machine using conda envs

bash \
execute/snakemake_local_run_conda_environments.sh \
../tests/integration/input/config.yml \
&& \
rm -rf output \
&& \
echo "Test completed successfully"
