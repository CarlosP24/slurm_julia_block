#!/bin/bash
source config/prologue.sh "$@"
if [ $? -ne 0 ]; then exit 1; fi
JOB_INFO=$(sbatch --parsable --export=ALL <<EOT
#!/bin/bash
#SBATCH --partition=esbirro
#SBATCH --ntasks-per-node=32
#SBATCH --nodes=7
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="logs/%A_%a.out"
#SBATCH --job-name="$*"
#SBATCH --mail-user=carlos.paya@csic.es
#SBATCH --mail-type=BEGIN,END,FAIL,TIME_LIMIT_80
#SBATCH --array=1-$ARRAY_SIZE

IFS=, read -r -a PARAMS <<< "\$PARAMS_STR"
PARAM="\${PARAMS[\$SLURM_ARRAY_TASK_ID-1]}"
echo Running \$PARAM
julia --project bin/launcher.jl "\$PARAM"
EOT
)
JOB_ID=$(echo "$JOB_INFO" | cut -d';' -f1)
source config/epilogue.sh $JOB_ID
