#!/usr/bin/env -S julia --project 
## Slurm header
#SBATCH --partition=most
#SBATCH --ntasks-per-node=192
#SBATCH --nodes=2
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

## Julia setup
script_path = ENV["SLURM_SUBMIT_DIR"]

using Pkg
Pkg.instantiate()
Pkg.resolve()
Pkg.precompile()

using Distributed, SlurmClusterManager
addprocs(SlurmManager())
@everywhere println("Active project is $(Base.active_project())")

## Run code
include("$(script_path)/src/main.jl")

## Clean up
rmprocs(workers()...)