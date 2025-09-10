CLUSTERS_CFG ?= config/clusters.yaml
CLUSTER ?= esbirro
ARG ?=

SHORT := $(shell yq e '.${CLUSTER}.short' $(CLUSTERS_CFG))
HOST := $(shell yq e '.${CLUSTER}.host' $(CLUSTERS_CFG))
RPATH1 := $(shell yq e '.${CLUSTER}.path' $(CLUSTERS_CFG))
CUR_DIR := $(notdir $(CURDIR))
RPATH := $(RPATH1)/$(CUR_DIR)
DPATH := $(RPATH)/data/
DPATH_LOCAL := data/

LAUNCHER := $(shell yq e '.${CLUSTER}.launcher' $(CLUSTERS_CFG))

SRC_DIR := .
EXCLUDE := --exclude='.git'
RSYNC_OPTS := -ax $(EXCLUDE)
RSYNC_OPTS_BACK := -auP

# ----------------------------------------
# Phony Targets
# ----------------------------------------
.PHONY: all deploy gen_launcher run sync

# ----------------------------------------
# Default Target
# ----------------------------------------
all:
	@echo "Available targets:"
	@echo "  make deploy		# Sync local code to $(CLUSTER)"
	@echo "  make ARG=<arg> run		# Run code on $(CLUSTER) with ARG <arg>"
	@echo "  make sync		# Sync data from $(CLUSTER) to local"
	@echo "  make gen_launcher	# Generate job launcher script"
	@echo ""
	@echo "Override CLUSTER on the command line:"
	@echo "  make CLUSTER=<cluster_name> deploy"

# ----------------------------------------
# Deploy: sync code to remote cluster
# ----------------------------------------
deploy:
	@if [ -z "$(SHORT)" ]; then \
	  echo "Error: Unknown cluster '$(CLUSTER)' in $(CLUSTERS_CFG)"; \
	  exit 1; \
	fi
	@echo "Deploying to $(CLUSTER) @ $(SHORT):$(RPATH)"
	ssh $(SHORT) "mkdir -p $(RPATH)"
	rsync $(RSYNC_OPTS) $(SRC_DIR)/ $(SHORT):$(RPATH)
# ----------------------------------------
# Gen Launcher: generate job launcher script
# ----------------------------------------
gen_launcher:
	@echo "Generating launcher.sh for cluster $(CLUSTER)"
	@echo "#!/bin/bash" > bin/launcher.sh
	@echo "source config/prologue.sh \"\$$@\"" >> bin/launcher.sh
	@echo "if [ \$$? -ne 0 ]; then exit 1; fi" >> bin/launcher.sh
	@echo "JOB_INFO=\$$(sbatch --parsable --export=ALL <<EOT" >> bin/launcher.sh
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
	@echo "julia --project bin/launcher.jl \"\\\$$PARAM\"" >> bin/launcher.sh
	@echo "EOT" >> bin/launcher.sh
	@echo ")" >> bin/launcher.sh
	@echo "JOB_ID=\$$(echo \"\$$JOB_INFO\" | cut -d';' -f1)" >> bin/launcher.sh
	@echo "source config/epilogue.sh \$$JOB_ID" >> bin/launcher.sh
	@chmod +x bin/launcher.sh
# ----------------------------------------
# Sync: sync data from remote cluster
# ----------------------------------------
sync:
	@if [ -z "$(SHORT)" ]; then \
	  echo "Error: Unknown cluster '$(CLUSTER)' in $(CLUSTERS_CFG)"; \
	  exit 1; \
	fi
	@echo "Syncing from $(CLUSTER) @ $(SHORT):$(RPATH)"
	rsync $(RSYNC_OPTS_BACK) $(SHORT):$(DPATH)/ $(DPATH_LOCAL)

# ----------------------------------------
# Run: execute on remote
# ---------------------------------------- 
run: gen_launcher deploy
	@echo "Running on $(CLUSTER) @ $(SHORT)"
	ssh -A $(SHORT) "bash -l -c 'cd $(RPATH) && bash bin/launcher.sh $(ARG)'"
	@echo "Run ended"
	@$(MAKE) sync
