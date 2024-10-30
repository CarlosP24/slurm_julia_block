#!/bin/bash
depot_path="$PWD/.julia_depot"
mkdir -p "$depot_path"
export JULIA_DEPOT_PATH="$depot_path"
export JULIA_PROJECT="$PWD"

julia --project prolog.jl