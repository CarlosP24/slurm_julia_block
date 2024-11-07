# Slurm Julia Block
Minimal working example of a distributed Julia calculation across different Slurm nodes.

This project makes use of [Distributed.jl](https://github.com/JuliaLang/Distributed.jl) and [SlurmClusterManager.jl](https://github.com/kleinhenz/SlurmClusterManager.jl).


## Usage
### Project code
All project-specific code resides in the `src` directory, while `Project.toml` and `Manifest.toml` must be in the main directory. The script executed by the Slurm launchers is `main.jl`. Other code can be included with relative paths to `src`.

Apart from this, the code can be written in the same way as it is done for single-node distributed calculations.


### Prologue
`config/prologue.jl` is responsible for instantiating the project and creating `./julia_depot`, where all precompiled code resides. If there are non-registered packages or a non-published GitHub branch is needed, they must be explicitly added through `ensure_package` and `ensure_package_branch`. For now, this has to be directly edited in `prologue.jl`.


### Launchers
Code is launched to a Slurm cluster through a bash script in the `bin` directory. This script contains the necessary `#SBATCH` flags, so it must be modified for each cluster and calculation. For example:

`````
#!/bin/bash
source config/prologue.sh "$@"
# Launch the job
sbatch --export=ALL <<EOT
#!/bin/bash
## Slurm header
#SBATCH --output="logs/%A_%a.out"
#SBATCH --job-name="${PWD##*/}_$ARRAY_SIZE"
#SBATCH --array=1-$ARRAY_SIZE
# Add here #SBATCH flags as needed.

# Deserialize
IFS=, read -r -a PARAMS <<< "\$PARAMS_STR"

# Select the parameter
PARAM="\${PARAMS[\$SLURM_ARRAY_TASK_ID-1]}"
echo "Running \$PARAM"

# Run the job
julia --project bin/launcher.jl "\$PARAM"

EOT
`````
The launcher can be given a list of command line parameters or a plain text file where each line is a parameter. A Slurm array is created, where each job takes one of those parameters and passes it to `main.jl`. For example:
`````
$ bash bin/launch_cluster.sh param1 param2
`````
will launch two jobs in an array, one with `param1` as the argument for `main.jl` and the other with `param2`.

## Key features
The primary goal of this code is to avoid precompilation on each node and provide a lighter user interface. To achieve this, a `./julia_depot` directory is created in the project directory. Slurm shares this directory with all nodes, so precompilation is performed only once. The `Manifest.toml` file is also shared in the same way.

Since this is done through environment variables exported to all nodes via `sbatch`, and the actual workers are launched through `srun`, **no SSH connection is required** between the computation nodes.

The same schematics are used to allow for the simple creation of Slurm arrays, where each element is passed as a command line argument to `main.jl`.