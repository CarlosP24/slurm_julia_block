#!/bin/bash
cd "$SLURM_SUBMIT_DIR"

# Check and update Manifest.toml
julia -e '
using Pkg
if isfilie("Manifest.toml")
    Pkg.resolve()
    Pkg.instantiate()
else
    println("Manifest.toml not found. Skipping update")
end
'