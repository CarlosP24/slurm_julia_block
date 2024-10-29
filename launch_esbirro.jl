#!/usr/bin/env -S julia --project
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

script_path = read(`scontrol show job $ENV["SLURM_JOBID"] | awk -F'Command=' '{print $2}'`, String)

## Julia setup
using Distributed
const maxprocs = 32
addprocs(max(0, maxprocs + 1 - nworkers()))

## Run code
#include("src/main.jl")
println(script_path)

## Clean up
rmprocs(workers()...)