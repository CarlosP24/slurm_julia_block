#!/usr/bin/env julia --project
## Slurm header
#SBATCH --partition=most
#SBATCH --ntasks=192
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

## Julia setup
using Distributed
const maxprocs = 96
addprocs(max(0, maxprocs + 1 - nworkers()))

@everywhere begin
    using Pkg
    Pkg.instantiate(); Pkg.precompile()
end 

## Run code
include("src/main.jl")

## Clean up
rmprocs(workers()...)