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

- To deploy code without running a job:  
    `make CLUSTER=<cluster> deploy`
- To sync results from the cluster manually:  
    `make CLUSTER=<cluster> sync`
- To regenerate the launcher script:  
    `make CLUSTER=<cluster> gen_launcher`

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

These explicit errors are designed to fail fast and provide clear feedback if your configuration or environment is not set up correctly.

### 3. `exit 2` errors in `epilogue.sh`

**Where:** During job monitoring, after job submission, in the `config/epilogue.sh` script.

**Cause:** The script exits with code 2 in the following cases:
    - The job enters a terminal or error state (such as `FAILED`, `CANCELLED`, `TIMEOUT`, `NODE_FAIL`, `OUT_OF_MEMORY`, etc.) instead of `RUNNING` or `PENDING`.
    - After running, if any job in the array is not in the `COMPLETED` state (e.g., failed, cancelled, or other non-successful state).

**How to fix:**
    - Check the job's output and error logs in the `logs/` directory for details on why the job failed or did not complete.

## License

See [LICENSE.md](LICENSE.md).

---

This project makes use of [Distributed.jl](https://github.com/JuliaLang/Distributed.jl) and [SlurmClusterManager.jl](https://github.com/kleinhenz/SlurmClusterManager.jl).
