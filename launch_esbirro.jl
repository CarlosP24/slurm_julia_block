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
using Pkg
Pkg.resolve()
Pkg.instantiate()

using JLD2, Quantica, ProgressMeter
using Distributed, SlurmClusterManager
addprocs(SlurmManager())

script_path = ENV["SLURM_SUBMIT_DIR"]

# @everywhere begin
#     using Pkg
#     Pkg.activate(script_path)
#     Pkg.instantiate()
# end

## Run code
# include("$(script_path)/src/main.jl")
@everywhere begin
    using Quantica
end
function mwe()
    lat = LP.honeycomb();
    model= @hopping((; t = 2.7) -> t*I);
    h = lat |> model

    g = h |> greenfunction()

    trng = range(0, 5, length = 100)
    ωrng = range(-1, 1, length = 100) .+ 1e-3im

    pts = Iterators.product(ωrng, trng)
    LDOS = pmap(pts) do pt 
        ω, t = pt
        return ldos(g[cells = (1, 1)])(ω; t)
    end
    return LDOS
end

LDOS = mwe()
save("LDOS.jld2", "LDOS", LDOS)

## Clean up
rmprocs(workers()...)