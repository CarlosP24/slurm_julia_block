#!/bin/bash
source prolog.sh
sbatch <<EOT
#!/bin/bash
## Slurm header
#SBATCH --partition=most
#SBATCH --ntasks-per-node=96
#SBATCH --nodes=2
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

julia --project launcher.jl
EOT