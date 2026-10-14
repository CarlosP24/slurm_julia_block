#!/bin/bash
# Sourced by bin/launcher.sh on the login node, before sbatch: Julia version, environment,
# package caches and (optionally) a system image. Everything exported here reaches the job
# (sbatch --export=ALL) and its workers.
if ! command -v juliaup &> /dev/null; then
    echo "juliaup could not be found. Please install juliaup."
    exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
depot_path="$script_dir/../.julia_depot"
mkdir -p "$depot_path"
mkdir -p "logs"
mkdir -p "data"
export JULIA_DEPOT_PATH="$depot_path"
export JULIA_PROJECT="$script_dir/.."

# Julia version: the one that resolved Manifest.toml, unless JULIAUP_CHANNEL is given
# (config/project.mk)
if [ -z "$JULIAUP_CHANNEL" ]; then
  JULIAUP_CHANNEL=$(sed -n 's/^julia_version = "\(.*\)"/\1/p' "$script_dir/../Manifest.toml")
fi
if [ -z "$JULIAUP_CHANNEL" ]; then
  echo "No julia_version in Manifest.toml and no JULIAUP_CHANNEL given."
  exit 1
fi
export JULIAUP_CHANNEL

if ! juliaup status | grep " $JULIAUP_CHANNEL "; then
  echo "Julia version $JULIAUP_CHANNEL not installed. Installing now..."
  juliaup add "$JULIAUP_CHANNEL"
fi

# Package caches (and the system image) are built here, on the login node, but loaded on
# the compute nodes. Build them for a generic set of x86 CPUs, as Julia's own binaries are,
# so that they stay valid when the compute nodes' CPU differs from the login node's;
# otherwise every worker recompiles at start-up. Only cached images are affected: the
# running code is still compiled for the node's own CPU. Caches built for another target
# are not detected as stale by Pkg, so they are rebuilt once when the target changes.
export JULIA_CPU_TARGET="${JULIA_CPU_TARGET:-generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1);x86-64-v4,-rdrnd,base(1)}"
target_stamp="$depot_path/cpu_target"
if [ -d "$depot_path/compiled" ] && [ "$(cat "$target_stamp" 2>/dev/null)" != "$JULIA_CPU_TARGET" ]; then
  echo "Package caches were built for another CPU target: rebuilding them (once)."
  rm -rf "$depot_path/compiled"
fi

julia --project "$script_dir/prologue.jl"

if [ $? -ne 0 ]; then
  echo "prologue.jl failed."
  exit 1
fi
echo "$JULIA_CPU_TARGET" > "$target_stamp"

# Optional system image (SYSIMAGE = 1 in config/project.mk): the project's packages, plus
# whatever config/sysimage_workload.jl runs, compiled ahead of time. Built once per
# Manifest, Julia version, CPU target and workload; reused afterwards.
export JULIA_SYSIMAGE=""
export JULIA_SYSIMAGE_FLAG=""
if [ "${SYSIMAGE:-0}" = 1 ]; then
  JULIA_SYSIMAGE=$(julia --project "$script_dir/sysimage.jl")
  if [ $? -ne 0 ] || [ ! -f "$JULIA_SYSIMAGE" ]; then
    echo "sysimage.jl failed."
    exit 1
  fi
  JULIA_SYSIMAGE_FLAG="-J$JULIA_SYSIMAGE"
  echo "Using system image $JULIA_SYSIMAGE"
fi

# Make the new caches visible to the compute nodes before the job starts (network FS)
sync

# Define parameters array
if [ -f "$1" ]; then
  PARAMS=($(cat "$1"))
else
  PARAMS=("$@")
fi
ARRAY_SIZE=${#PARAMS[@]}
export ARRAY_SIZE

if [ $ARRAY_SIZE -eq 0 ]; then
  echo "No parameters provided"
  exit 1
fi

# Serialize the array into a string
PARAMS_STR=$(IFS=,; echo "${PARAMS[*]}")
export PARAMS_STR
