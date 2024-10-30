#!/usr/bin/env -S julia --project

## Julia setup
script_path = ENV["SLURM_SUBMIT_DIR"]

using Distributed, SlurmClusterManager
@time addprocs(SlurmManager())

## Run code
include("$(script_path)/src/main.jl")

## Clean up
rmprocs(workers()...)