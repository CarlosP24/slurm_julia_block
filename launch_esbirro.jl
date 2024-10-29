#!/usr/bin/env -S julia --project
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

# Get script_path to use include
# scontrol_cmd = `scontrol show job $(ENV["SLURM_JOBID"])`
# awk_cmd = `awk -F'Command=' '{print $2}'`
# script_path = read(pipeline(scontrol_cmd, awk_cmd), String) |> strip |> dirname
script_path = ENV["SLURM_SUBMIT_DIR"]

## Julia setup
using Pkg
Pkg.resolve()
Pkg.instantiate()

using Distributed, SlurmClusterManager
addprocs(SlurmManager())

@everywhere begin
    using Pkg
    Pkg.activate(script_path)
    Pkg.instantiate()
  end

## Run code
include("$(script_path)/src/main.jl")

## Clean up
rmprocs(workers()...)