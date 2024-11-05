#!/bin/bash
source config/prologue.sh
if [ $? -ne 0 ]; then
  exit 1
fi
sbatch <<EOT
#!/bin/bash
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="logs/%j.out"
#SBATCH --job-name="${PWD##*/}"

julia --project bin/launcher.jl "$@"
EOT