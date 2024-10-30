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

## Julia setup
script_path = ENV["SLURM_SUBMIT_DIR"]
available_workers = parse(Int, ENV["SLURM_NTASKS"])
depot_path = "/local/cap/.julia_depot"
ENV["JULIA_DEPOT_PATH"] = depot_path

using Pkg
Pkg.resolve()
Pkg.instantiate()
Pkg.precompile()

using Distributed, ClusterManagers
addprocs_slurm(available_workers)
@everywhere global ENV["JULIA_DEPOT_PATH"] = depot_path

## Run code
include("$(script_path)/src/main.jl")
# @everywhere using Sockets
# hostnames = [@spawn gethostname() for _ in 1:nworkers()]
# results = fetch.(hostnames)
# println("Hostnames of workers: ", results)
## Clean up
rmprocs(workers()...)