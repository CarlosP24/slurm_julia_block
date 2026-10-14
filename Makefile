# Cluster pipeline, from the template github.com/CarlosP24/slurm_julia_block.
# Keep this file identical across projects: per-project settings go in the optional
# config/project.mk, which may set
#   CLUSTER          default cluster (the command line still wins: make CLUSTER=<name> ...)
#   DEPLOY_DATA      subfolders of data/ that runs read as input and deploy must upload
#                    (e.g. DEPLOY_DATA = prl25 inputs); the rest of data/ only comes back
#   DEPLOY_EXCLUDE   paths never uploaded (default below)
#   JULIA_FLAGS      extra flags for the job's julia (e.g. --compiled-modules=no)
#   SBATCH_FLAGS     extra flags for sbatch (e.g. -v)
#   JULIAUP_CHANNEL  Julia version (default: julia_version in Manifest.toml)
#   SYSIMAGE         1 to run jobs on a system image built by config/sysimage.jl
-include config/project.mk

CLUSTERS_CFG ?= config/clusters.yaml
CLUSTER ?= esbirro
ARG ?=
JOB ?=
DEPLOY_DATA ?=
DEPLOY_EXCLUDE ?= /.git /wip /figures /logs /.julia_depot
JULIA_FLAGS ?=
SBATCH_FLAGS ?=
JULIAUP_CHANNEL ?=
SYSIMAGE ?=

SHORT := $(shell yq e '.${CLUSTER}.short' $(CLUSTERS_CFG))
HOST := $(shell yq e '.${CLUSTER}.host' $(CLUSTERS_CFG))
RPATH1 := $(shell yq e '.${CLUSTER}.path' $(CLUSTERS_CFG))
CUR_DIR := $(notdir $(CURDIR))
RPATH := $(RPATH1)/$(CUR_DIR)
DPATH := $(RPATH)/data/
DPATH_LOCAL := data/

LAUNCHER := $(shell yq e '.${CLUSTER}.launcher' $(CLUSTERS_CFG))

SRC_DIR := .
# data/ is output: only the DEPLOY_DATA subfolders go up
EXCLUDE := $(foreach p,$(DEPLOY_EXCLUDE),--exclude='$(p)') \
	--include='/data/' $(foreach p,$(DEPLOY_DATA),--include='/data/$(p)/***') --exclude='/data/*'
RSYNC_OPTS := -ax $(EXCLUDE)
# checkpoints of unfinished runs stay on the cluster
RSYNC_OPTS_BACK := -auP --exclude='.checkpoints'
REMOTE_ENV := $(if $(JULIAUP_CHANNEL),JULIAUP_CHANNEL=$(JULIAUP_CHANNEL)) \
	$(if $(SYSIMAGE),SYSIMAGE=$(SYSIMAGE))
# recursive (=), so that $$ survives to the remote shell
JOB_REF = $(if $(JOB),$(JOB),\$$(cat logs/last_job))

# ----------------------------------------
# Phony Targets
# ----------------------------------------
.PHONY: all check deploy gen_launcher submit watch status run sync

# ----------------------------------------
# Default Target
# ----------------------------------------
all:
	@echo "Available targets:"
	@echo "  make deploy		# Sync local code to $(CLUSTER)"
	@echo "  make ARG=<arg> run	# submit + watch + sync"
	@echo "  make ARG=<arg> submit	# Deploy and submit, return at once (job id in logs/last_job)"
	@echo "  make watch		# Follow the last job until it ends (JOB=<id> for another)"
	@echo "  make status		# One-shot state and last log lines of the last job"
	@echo "  make sync		# Sync data from $(CLUSTER) to local"
	@echo "  make gen_launcher	# Generate job launcher script"
	@echo ""
	@echo "Override CLUSTER on the command line:"
	@echo "  make CLUSTER=<cluster_name> deploy"

check:
	@if [ -z "$(SHORT)" ] || [ "$(SHORT)" = "null" ]; then \
	  echo "Error: Unknown cluster '$(CLUSTER)' in $(CLUSTERS_CFG)"; \
	  exit 1; \
	fi

# ----------------------------------------
# Deploy: sync code to remote cluster
# ----------------------------------------
deploy: check
	@echo "Deploying to $(CLUSTER) @ $(SHORT):$(RPATH)"
	ssh $(SHORT) "mkdir -p $(RPATH)"
	rsync $(RSYNC_OPTS) $(SRC_DIR)/ $(SHORT):$(RPATH)
# ----------------------------------------
# Gen Launcher: generate job launcher script
# ----------------------------------------
gen_launcher: check
	@echo "Generating launcher.sh for cluster $(CLUSTER)"
	@echo "#!/bin/bash" > bin/launcher.sh
	@echo "source config/prologue.sh \"\$$@\"" >> bin/launcher.sh
	@echo "if [ \$$? -ne 0 ]; then exit 1; fi" >> bin/launcher.sh
	@echo "JOB_INFO=\$$(sbatch $(SBATCH_FLAGS) --parsable --export=ALL <<EOT" >> bin/launcher.sh
	@echo "#!/bin/bash" >> bin/launcher.sh
	@if yq e '.${CLUSTER}.partition' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --partition=$$(yq e '.${CLUSTER}.partition' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@if yq e '.${CLUSTER}.ntasks_per_node' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --ntasks-per-node=$$(yq e '.${CLUSTER}.ntasks_per_node' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@if yq e '.${CLUSTER}.nodes' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --nodes=$$(yq e '.${CLUSTER}.nodes' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@if yq e '.${CLUSTER}.ntasks' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --ntasks=$$(yq e '.${CLUSTER}.ntasks' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@if yq e '.${CLUSTER}.cpus_per_task' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --cpus-per-task=$$(yq e '.${CLUSTER}.cpus_per_task' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@if yq e '.${CLUSTER}.mem_per_cpu' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --mem-per-cpu=$$(yq e '.${CLUSTER}.mem_per_cpu' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@if yq e '.${CLUSTER}.time' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --time=$$(yq e '.${CLUSTER}.time' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@if yq e '.${CLUSTER}.where' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --nodelist=$$(yq e '.${CLUSTER}.where' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@echo "#SBATCH --output=\"logs/%A_%a.out\"" >> bin/launcher.sh
	@echo "#SBATCH --job-name=\"\$$*\"" >> bin/launcher.sh
	@if yq e '.${CLUSTER}.mail_user' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --mail-user=$$(yq e '.${CLUSTER}.mail_user' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@if yq e '.${CLUSTER}.mail_type' $(CLUSTERS_CFG) | grep -vq 'null'; then \
		echo "#SBATCH --mail-type=$$(yq e '.${CLUSTER}.mail_type' $(CLUSTERS_CFG))" >> bin/launcher.sh; \
	fi
	@echo "#SBATCH --array=1-\$$ARRAY_SIZE" >> bin/launcher.sh
	@echo "" >> bin/launcher.sh
	@echo "IFS=, read -r -a PARAMS <<< \"\\\$$PARAMS_STR\"" >> bin/launcher.sh
	@echo "PARAM=\"\\\$${PARAMS[\\\$$SLURM_ARRAY_TASK_ID-1]}\"" >> bin/launcher.sh
	@echo "echo Running \\\$$PARAM" >> bin/launcher.sh
	@echo "julia $(JULIA_FLAGS) \$$JULIA_SYSIMAGE_FLAG --project bin/launcher.jl \"\\\$$PARAM\"" >> bin/launcher.sh
	@echo "EOT" >> bin/launcher.sh
	@echo ")" >> bin/launcher.sh
	@echo "JOB_ID=\$$(echo \"\$$JOB_INFO\" | cut -d';' -f1)" >> bin/launcher.sh
	@echo 'if ! [[ "$$JOB_ID" =~ ^[0-9]+$$ ]]; then echo "Submission failed: $$JOB_INFO"; exit 2; fi' >> bin/launcher.sh
	@echo 'echo "$$JOB_ID" > logs/last_job' >> bin/launcher.sh
	@echo 'echo "Submitted job $$JOB_ID"' >> bin/launcher.sh
	@echo 'if [ "$${WATCH:-1}" = 1 ]; then source config/epilogue.sh $$JOB_ID; fi' >> bin/launcher.sh
	@chmod +x bin/launcher.sh
# ----------------------------------------
# Sync: sync data from remote cluster
# ----------------------------------------
sync: check
	@echo "Syncing from $(CLUSTER) @ $(SHORT):$(RPATH)"
	rsync $(RSYNC_OPTS_BACK) $(SHORT):$(DPATH)/ $(DPATH_LOCAL)

# ----------------------------------------
# Submit: deploy and submit, without waiting for the job
# ----------------------------------------
submit: gen_launcher deploy
	@echo "Submitting on $(CLUSTER) @ $(SHORT)"
	ssh -A $(SHORT) "bash -l -c 'cd $(RPATH) && $(REMOTE_ENV) WATCH=0 bash bin/launcher.sh $(ARG)'"

# ----------------------------------------
# Watch / status: follow a submitted job (safe to interrupt and rerun)
# ----------------------------------------
watch: check
	ssh $(SHORT) "bash -l -c 'cd $(RPATH) && bash config/epilogue.sh $(JOB_REF)'"

status: check
	@ssh $(SHORT) "bash -l -c 'cd $(RPATH) && J=$(JOB_REF) && squeue -j \$$J -o \"%i %T %M %N %R\"; for f in logs/\$${J}_*.out; do echo == \$$f; tail -n 5 \$$f; done'"

# ----------------------------------------
# Run: submit, watch until the job ends, sync
# ----------------------------------------
run: submit
	@$(MAKE) --no-print-directory CLUSTER=$(CLUSTER) watch
	@echo "Run ended"
	@$(MAKE) --no-print-directory CLUSTER=$(CLUSTER) sync
