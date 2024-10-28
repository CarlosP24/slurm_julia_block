#!/usr/bin/env -S julia --project
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

## Julia setup
using Distributed
const maxprocs = 32
addprocs(max(0, maxprocs + 1 - nworkers()))

@everywhere begin
    using Pkg
    Pkg.instantiate(); Pkg.precompile()
end 

## Run code
include("src/main.jl")

## Clean up
rmprocs(workers()...)