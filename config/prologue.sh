#!/bin/bash
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
depot_path="$script_dir/../.julia_depot"
mkdir -p "$depot_path"
mkdir -p "logs"
mkdir -p "data"
export JULIA_DEPOT_PATH="$depot_path"
export JULIA_PROJECT="$script_dir/.."

julia --project "$script_dir/prologue.jl"