#!/bin/bash
source prolog.sh
sbatch <<EOT
#!/usr/bin/env -S julia --project
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

## Julia setup
script_path = ENV["SLURM_SUBMIT_DIR"]

using Distributed, SlurmClusterManager
addprocs(SlurmManager())

## Run code
include("$(script_path)/src/main.jl")

## Clean up
rmprocs(workers()...)

EOT