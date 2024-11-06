# Slurm Julia Block
Minimal working example of a distributed julia calculation across different slurm nodes.

Makes use of [Distributed.jl](https://github.com/JuliaLang/Distributed.jl) and [SlurmClusterManager.jl](https://github.com/kleinhenz/SlurmClusterManager.jl).

## Usage
All code should reside in the `src` directory. It must run through `src/main.jl`. This script can use relative path names and be written just taking into account the usual stuff for distributed computation (`@everywhere` and so).

All slurm parameters are in a script `launch_cluster.sh`. We just need to do `bash bin/launch_cluster.sh args...` in an access node. If `args` is a single string, it will be passed to `main.jl` as a command line argument. If it is a set of strings (or a file with one string per line), slurm will launch an array with each `arg` as the argument for `main.jl` in that job.

## Hows and whys
`prologue.sh` sets up the necessary julia env variables. It points the `JULIA_DEPOT_PATH` and `JULIA_PROJECT` to a common place for all nodes, so the precompiled files and `Manifest.toml` are accessible to all workers when launched. 

This has to be done before the actual `sbatch` allocation due to Julia inner stuff (see the [documentation](https://docs.julialang.org/en/v1/manual/environment-variables/#JULIA_DEPOT_PATH)).

Then, it instantiates, resolves and precompile the project, once and for all workers through `prologue.jl`.

`launcher.jl` just adds the workers, runs the code in `src/main.jl` and cleans up for safety.

The header before the actual `sbatch` script passes the command line arguments to slurm and calculates the size of the necessary array. Inside the `sbatch` script, before running julia, the command line arguments are deserialized and each array element gets one assigned.

