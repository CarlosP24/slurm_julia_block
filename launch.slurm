#!/bin/bash
mkdir -p slurm.out
sbatch <<EOT
#!/bin/bash
#SBATCH -p long
#SBATCH --nodes=$1
#SBATCH --ntasks-per-node=48
#SBATCH --output=slurm.out/%j.out
#SBATCH --job-name="test"

export SLURM_NODEFILE=`generate_pbs_nodefile.pl`

julia --machine-file $SLURM_NODEFILE src/main.jl
EOT