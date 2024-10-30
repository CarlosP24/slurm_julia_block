# Slurm Julia Block
Minimal working example of a distributed julia calculation across different slurm nodes.

Makes use of [Distributed.jl](https://github.com/JuliaLang/Distributed.jl) and [SlurmClusterManager.jl](https://github.com/kleinhenz/SlurmClusterManager.jl).

## Usage
All code should reside in the `src` directory. It must run through `src/main.jl`. This script can use relative path names and be written just taking into account the usual stuff for distributed computation (`@evereywhere` and so).

All slurm parameters are in a scritp `launch_cluster.sh` that looks like
`````
#!/bin/bash
source prolog.sh
sbatch <<EOT
#!/bin/bash
## Slurm header
#SBATCH --partition=esbirro
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2G
#SBATCH --output="slurm.out/%j.out"

julia --project launcher.jl
EOT
`````

We just need to do `bash launch_cluster.sh` in an access node.

## Hows and whys
`prolog.sh` sets up the necessary julia env variables. It points the `JULIA_DEPOT_PATH` and `JULIA_PROJECT` to a common place for all nodes, so the precompiled files and `Manifest.toml` are accessible to all workers when launched. 

This has to be done before the actual `sbatch` allocation due to Julia inner stuff (see the [documentation](https://docs.julialang.org/en/v1/manual/environment-variables/#JULIA_DEPOT_PATH)).

Then, it instantiates, resolves and precompile the project, once and for all workers through `prolog.jl`.

`launcher.jl` just adds the workers, runs the code in `src/main.jl` and cleans up for safety.

