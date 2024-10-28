#!/bin/bash
mkdir -p slurm.out
sbatch <<EOT
#!/bin/bash
#SBATCH -p long
#SBATCH --nodes=$1
#SBATCH --ntasks-per-node=47
#SBATCH --output=slurm.out/%j.out
#SBATCH --job-name="test"

export SLURM_NODELIST=`scontrol show hostnames $SLURM_JOB_NODELIST`
export SLURM_NODEFILE=`generate_pbs_nodefile.pl`

julia --machine-file $SLURM_NODEFILE src/main.jl
EOT