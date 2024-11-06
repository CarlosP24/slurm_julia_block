#!/bin/bash
source config/prologue.sh
if [ $? -ne 0 ]; then
  exit 1
fi
# Define parameters array
if [ -f "$1" ]; then
  PARAMS=($(cat "$1"))
else
  PARAMS=("$@")
fi
ARRAY_SIZE=${#PARAMS[@]}

if [ $ARRAY_SIZE -eq 0 ]; then
  echo "No parameters provided"
  exit 1
fi

# Serialize the array into a string
PARAMS_STR=$(IFS=,; echo "${PARAMS[*]}")
export PARAMS_STR

# Launch the job
sbatch --export=ALL <<EOT
#!/bin/bash
## Slurm header
#SBATCH --partition=most
#SBATCH --ntasks-per-node=196
#SBATCH --nodes=2
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="logs/%A_%a.out"
#SBATCH --job-name="${PWD##*/}_$ARRAY_SIZE"
#SBATCH --mail-user=carlos.paya@csic.es
#SBATCH --mail-type=BEGIN,END,FAIL,TIME_LIMIT_80
#SBATCH --array=1-$ARRAY_SIZE

# Deserialize
IFS=, read -r -a PARAMS <<< "\$PARAMS_STR"

# Select the parameter
PARAM="\${PARAMS[\$SLURM_ARRAY_TASK_ID-1]}"
echo "Running \$PARAM"

# Run the job
julia --project bin/launcher.jl "\$PARAM"
EOT