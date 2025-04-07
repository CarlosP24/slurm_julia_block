#!/bin/bash
source config/prologue.sh "$@"
if [ $? -ne 0 ]; then
  exit 1
fi
# Launch the job
sbatch --export=ALL <<EOT
#!/bin/bash
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks-per-node=32
#SBATCH --nodes=2
#SBATCH --exclude=es8
#SBATCH --cpus-per-task=1
##SBATCH --mem-per-cpu=2G
#SBATCH --output="logs/%A_%a.out"
#SBATCH --job-name="$*"
#SBATCH --mail-user=carlos.paya@csic.es
#SBATCH --mail-type=END,FAIL
#SBATCH --array=1-$ARRAY_SIZE

# Deserialize
IFS=, read -r -a PARAMS <<< "\$PARAMS_STR"

# Select the parameter
PARAM="\${PARAMS[\$SLURM_ARRAY_TASK_ID-1]}"
echo "Running \$PARAM"

# Run the job
julia --project bin/launcher.jl "\$PARAM"

EOT