#!/usr/bin/env -S julia --project
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

run(`export SCRIPT_PATH=$(scontrol show job $SLURM_JOBID | awk -F='/Command=/{print $2}')`)

## Julia setup
using Distributed
const maxprocs = 32
addprocs(max(0, maxprocs + 1 - nworkers()))

## Run code
#include("src/main.jl")
println(ENV["SCRIPT_PATH"])

## Clean up
rmprocs(workers()...)