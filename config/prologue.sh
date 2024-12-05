#!/bin/bash
# Ensure juliaup is installed and use the specific version of Julia
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

export JULIAUP_CHANNEL=1.11.1

if ! juliaup status | grep " $JULIAUP_CHANNEL "; then
  echo "Julia version $JULIAUP_CHANNEL not installed. Installing now..."
  juliaup add "$JULIAUP_CHANNEL"
fi 

julia --project "$script_dir/prologue.jl"

if [ $? -ne 0 ]; then
  echo "prologue.jl failed."
  exit 1
fi


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