#!/usr/bin/env -S julia --project
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

# Construct the scontrol command
scontrol_cmd = `scontrol show job $(ENV["SLURM_JOBID"])`

# Construct the awk command separately
awk_cmd = `awk -F'Command=' '{print $2}'`

# Use pipeline to pass the output of scontrol_cmd to awk_cmd
script_path = read(pipeline(scontrol_cmd, awk_cmd), String) |> dirname

## Julia setup
using Distributed
const maxprocs = 32
addprocs(max(0, maxprocs + 1 - nworkers()))

## Run code
include("$(script_path)/src/main.jl")

## Clean up
rmprocs(workers()...)