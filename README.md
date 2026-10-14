# Slurm Julia Block

Minimal working example of a distributed Julia calculation across different Slurm nodes.

This project provides a template for running Julia-based parallel computations on remote clusters managed by Slurm. It automates code deployment, job submission, monitoring, and result synchronization, so you can focus on your scientific code in `src/` and let the infrastructure handle the rest.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Quick Start](#quick-start)
3. [How It Works](#how-it-works)
4. [Advanced Usage](#advanced-usage)
5. [Requirements](#requirements)
6. [Notes](#notes)
7. [Troubleshooting & Common Errors](#troubleshooting--common-errors)
8. [License](#license)

## Features

- **Automatic deployment**: Sync your code to the remote cluster with a single command.
- **Flexible cluster configuration**: Easily switch between clusters using a YAML config.
- **Automated job submission**: Generates and submits Slurm job scripts tailored to each cluster.
- **Parallel execution**: Handles all Julia parallelization and Slurm array job details for you.
- **Result synchronization**: Automatically syncs results back to your local machine after job completion.
- **Separation of concerns**: You only need to write your scientific code in `src/` (especially `main.jl`); all cluster and parallelization logic is handled for you.
- **Pinned environments**: the job uses exactly the Julia version and packages of your `Manifest.toml`; the cluster never resolves or upgrades them.
- **Live logs**: the job's output is flushed to `logs/` every 10 s, with timestamps for the worker start-up.
- **Checkpointed `pmap`**: `ckpt_pmap` sizes its chunks automatically, survives dead workers and resumes interrupted runs.
- **Optional system image**: compile your packages (and a sample of your workload) ahead of time, so that workers start computing at once.

## Project Structure

```text
.
├── bin/                # Launch scripts (auto-generated and helpers)
├── config/             # Cluster configuration and prologue/epilogue scripts
├── data/               # Data/results (synced from cluster)
├── plots/              # Plotting scripts and related files
├── src/                # Your Julia source code (main.jl, functions.jl, etc.)
├── Makefile            # Main interface for deployment and job management
├── Project.toml        # Julia project dependencies
├── Manifest.toml       # Julia project manifest
└── README.md           # This file
```

## Quick Start

### 1. Configure Your Clusters

Edit `config/clusters.yaml` to define your clusters. Each cluster entry should specify SSH info, Slurm options, and paths. Example:

```yaml
esbirro:
    short: es1
    host: esbirro.example.com
    path: /remote/home
    partition: compute
    ntasks_per_node: 4
    nodes: 2
    ntasks: 8
    cpus_per_task: 1
    mem_per_cpu: 2G
    mail_user: your@email.com
    mail_type: END,FAIL
```

Notice that `short`is the handle through which passwordless ssh is configured. That is, you should be able to do `ssh es1` from your terminal without password prompt.

### 2. Write Your Julia Code

- Place your main computation in `src/main.jl`.
- Add helper functions in `src/functions.jl` or other files as needed.
- Your code should be written as if running locally from `main.jl`; all parallelization and cluster setup is handled for you.

### 3. Launch a Calculation

From your project root, run:

```sh
make ARG="<arg>" CLUSTER=<cluster> run
```

- Replace `<arg>` with the argument your `main.jl` expects.
- Replace `<cluster>` with the name of the cluster as defined in `config/clusters.yaml`.

**Example:**

```sh
make ARG="input1" CLUSTER=esbirro run
```

This will:

1. Generate a Slurm launcher script tailored to the cluster.
2. Deploy your code to the remote cluster.
3. Submit the job to Slurm, handling all parallelization details.
4. Print the job status in your terminal until it finishes.
5. Sync the results from the cluster's `data/` directory back to your local `data/`.

### 4. Check Results

After the job completes, results will be available in your local `data/` directory.

## How It Works

- **Makefile**: Orchestrates deployment, job script generation, job submission, and result synchronization.
- **bin/launcher.sh**: Auto-generated Slurm job script, customized for each cluster.
- **config/prologue.sh / prologue.jl**: Set up the environment and Julia parallel workers on the cluster.
- **src/main.jl**: Your main Julia entry point. All parallelization is handled for you; just write your computation as usual.
- **Result Sync**: After the job, results in `data/` on the cluster are synced back to your local `data/`.

## Advanced Usage

### Submit, watch and sync separately

`make run` is `submit` + `watch` + `sync`. The job never depends on your terminal, so you can
also split it:

- `make ARG=<arg> submit`: deploy and submit, then return (the job id goes to `logs/last_job` on the cluster);
- `make watch`: follow the last job until it ends; interrupt it and run it again at any time (`JOB=<id>` for another job);
- `make status`: one-shot state and last log lines of the last job;
- `make sync`: bring `data/` back (also after an interrupted `run`);
- `make deploy`, `make gen_launcher`: deploy only, or regenerate `bin/launcher.sh`.

### Per-project settings: `config/project.mk`

Keep `Makefile`, `bin/` and `config/*.sh|*.jl` identical to the template and put what differs
in an optional `config/project.mk`:

```make
CLUSTER = atto               # default cluster
DEPLOY_DATA = prl25          # data/ subfolders the runs read as input (data/ is otherwise not uploaded)
DEPLOY_EXCLUDE = /.git /wip /figures /logs /.julia_depot /seed   # never uploaded
JULIA_FLAGS = --compiled-modules=no
SBATCH_FLAGS = -v
JULIAUP_CHANNEL = 1.12.4     # default: julia_version of Manifest.toml
SYSIMAGE = 1                 # run on a system image (below)
```

### Checkpointed `pmap`

`bin/launcher.jl` provides `ckpt_pmap`, a drop-in for `pmap` in long runs:

```julia
vals = ckpt_pmap(f, points; name = "panel_a")    # instead of pmap(f, points; batch_size = 64)
```

It sizes the chunks on the fly (about 20 s each, smaller near the end), sends `f` once per
worker, moves the chunk of a dead worker to another one, logs progress with an ETA, and saves
every finished chunk in `data/.checkpoints/`. If the job dies, the next run with the same `name`
and `points` resumes from there (set `CKPT_RESUME=0` after changing the code but not the points).
For local runs, `include("bin/ckpt_pmap.jl")` at top level after `addprocs`.

### System image

With `SYSIMAGE = 1`, the prologue builds (once per Manifest, Julia version and workload) a
system image with every package of `Project.toml`, and the job and its workers run on it. Add
a `config/sysimage_workload.jl` that runs a tiny version of a real calculation: the methods it
compiles are then ready in every worker, which otherwise compiles them on its first call.

### CPU target

Package caches are built on the login node for a generic set of x86 CPUs
(`JULIA_CPU_TARGET` in `config/prologue.sh`), so they stay valid on compute nodes with another
CPU. The code itself is still compiled for each node's CPU.

## Requirements

- Julia (with `Distributed.jl` and `SlurmClusterManager.jl` in your `Project.toml`)
- `yq` (YAML processor) installed locally for Makefile parsing
- SSH access to your clusters
- Slurm installed on the remote cluster

## Notes

- All cluster-specific options (partitions, resources, etc.) are set in `config/clusters.yaml`.
- The workflow assumes your code is run via `src/main.jl`.
- You can add more clusters by extending `config/clusters.yaml`.

## Troubleshooting & Common Errors

The workflow includes some explicit error checks to help you quickly diagnose configuration or environment issues:

### 1. `Error: Unknown cluster '<cluster>' in <config/clusters.yaml>`

**Where:** During `make deploy` or `make sync` (and any target that uses these).

**Cause:** The `CLUSTER` variable you provided does not match any entry in your `config/clusters.yaml` file, or the `short` field is missing for that cluster.

### 2. `exit 1` after prologue failure

**Where:** At the start of a Slurm job, in the generated `bin/launcher.sh` script.

**Cause:** The `config/prologue.sh` script failed (non-zero exit code). This script is responsible for setting up the environment on the cluster (e.g., loading modules, activating environments).

**How to fix:**
    - Check the contents and logic of `config/prologue.sh`.
    - Make sure all commands in the prologue succeed on the cluster (e.g., `module load julia` or similar).
    - Check the job's output log for error messages from the prologue.
    - If `Pkg.instantiate` failed, the Manifest cannot be installed as it is: fix it locally (`julia --project -e 'using Pkg; Pkg.instantiate()'`) and deploy again. The prologue never resolves or upgrades packages on the cluster.

These explicit errors are designed to fail fast and provide clear feedback if your configuration or environment is not set up correctly.

### 3. `exit 2` errors in `epilogue.sh`

**Where:** During job monitoring, after job submission, in the `config/epilogue.sh` script.

**Cause:** The script exits with code 2 in the following cases:
    - The job enters a terminal or error state (such as `FAILED`, `CANCELLED`, `TIMEOUT`, `NODE_FAIL`, `OUT_OF_MEMORY`, etc.) instead of `RUNNING` or `PENDING`.
    - After running, if any job in the array is not in the `COMPLETED` state (e.g., failed, cancelled, or other non-successful state).

**How to fix:**
    - Check the job's output and error logs in the `logs/` directory for details on why the job failed or did not complete.

### 4. The log shows only `Running <arg>` for a long time

Julia buffers its output when it goes to a file; `bin/launcher.jl` flushes it every 10 s, but
only while the master waits (e.g. inside `pmap`). Check the timestamps of `starting workers` and
`workers ready`. A long silence after `workers ready` and before the first result is usually each
worker compiling your code on its first call: a system image with a workload removes it.

## License

See [LICENSE.md](LICENSE.md).

---

This project makes use of [Distributed.jl](https://github.com/JuliaLang/Distributed.jl) and [SlurmClusterManager.jl](https://github.com/kleinhenz/SlurmClusterManager.jl).
