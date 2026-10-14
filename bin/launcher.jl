#!/usr/bin/env -S julia --project

## Julia setup
script_path = ENV["SLURM_SUBMIT_DIR"]

using Distributed, SlurmClusterManager, Dates

# Slurm sends stdout/stderr to a file, which Julia block-buffers: without this, logs/*.out
# shows nothing until the job ends. Fires whenever the master yields (e.g. inside pmap).
const _flusher = Timer(_ -> (flush(stdout); flush(stderr)), 0; interval = 10)

println(now(), " starting workers")
@time addprocs(SlurmManager())

# One BLAS thread per CPU of the task. Julia's default is CPU_THREADS ÷ 2 per process
# (96 in each of the 128 workers of an atto node).
@everywhere using LinearAlgebra
@everywhere BLAS.set_num_threads(parse(Int, get(ENV, "SLURM_CPUS_PER_TASK", "1")))
println(now(), " ", nworkers(), " workers ready")

## Run code
include("$(script_path)/src/main.jl")

## Clean up
rmprocs(workers()...)
close(_flusher)
