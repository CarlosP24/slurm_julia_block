#!/bin/bash
sbatch <<EOT
#!/bin/bash
#SBATCH -p esbirro
#SBATCH --nodes=2
#SBATCH --exclude=es1
#SBATCH --exclusive
#SBATCH --output=slurm.out/$2_%j.out
#SBATCH --error=slurm.out/$2_%j.err
#SBATCH --job-name=$2

scontrol show hostnames $SLURM_JOB_NODELIST > machinefile

julia --project MWE.jl $1 $2
EOT