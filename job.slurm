#!/bin/bash
#SBATCH -p esbirro
#SBATCH --nodes=2
#SBATCH --exclude=es1
#SBATCH --exclusive
#SBATCH --output=slurm.out/%j.out

scontrol show hostnames $SLURM_JOB_NODELIST > machinefile
scontrol update JobID=$SLURM_JOB_ID name=$1

julia --project MWE.jl $1