# Makefile

# Use bash with strict flags for all recipes
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# Use a custom recipe prefix to avoid TAB requirements (GNU make 4.x+)
.RECIPEPREFIX := >

# Debug (set DEBUG=1 to enable command tracing)
DEBUG ?= 0
ifeq ($(DEBUG),1)
  TRACE := set -x;
else
  TRACE :=
endif

# --------------------------------------------------------------------
# Paths for annotated pipeline (glossary)
# --------------------------------------------------------------------
INPUT    ?= data/tosa-zh.json
ZISK     ?= $(shell nix build --no-link --print-out-paths .\#zisk-conventions)
OUT      ?= build/glossary.json           # auto-generated global glossary
FILLED   ?= build/out.json                # per-paragraph filled JSON
EDITED   ?= data/glossary.edited.json     # user-edited glossary
DST      ?= data/final/glossary.json      # staged final glossary

# Prefer EDITED if it exists; otherwise use OUT (trim whitespace)
GLOSSARY ?= $(if $(wildcard $(EDITED)),$(EDITED),$(OUT))
GLOSSARY := $(strip $(GLOSSARY))

# Where to publish build results
ARTIFACTS ?= artifacts

# --------------------------------------------------------------------
# RAW → artifacts pipeline (three extractor scripts)
# --------------------------------------------------------------------
SCRIPTS_DIR ?= scripts

SCRIPT_EXTRACT_FULL      ?= $(SCRIPTS_DIR)/extract_chinese_full.sh
SCRIPT_EXTRACT_BY_DAYS   ?= $(SCRIPTS_DIR)/extract_chinese_by_days.sh
SCRIPT_EXTRACT_PARALLEL  ?= $(SCRIPTS_DIR)/extract_parallel_texts.sh

# RAW source and outputs
RAW        ?= tosa-translation/tosa.json
INPUT_JSON ?= tosa-zh.json
PARALLEL   ?= artifacts/zh-jp-parallel-texts.json
BYDAY      ?= artifacts/zh-translation-by-day.json

# Optional extra args for the three extractors
FULL_ARGS    ?=
BY_DAYS_ARGS ?=
PAR_ARGS     ?=

# --------------------------------------------------------------------
# Commands (flake apps; escape '#' so make does not treat it as a comment)
# --------------------------------------------------------------------
GEN  ?= nix run .\#generate-glossary --
FILL ?= nix run .\#fill-glossary --

# Load optional overrides
-include .env

# --------------------------------------------------------------------
# Phony targets
# --------------------------------------------------------------------
.PHONY: help dirs update raw-full raw-by-days raw-parallel raw-all \
        glossary fill stage activate publish publish-edited publish-clean \
        clean clean-raw print

help: ## Show help
> awk 'BEGIN{FS=":.*##"; printf "\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/{printf "  \033[1m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dirs: ## Create output directories
> $(TRACE) mkdir -p $(dir $(OUT)) $(dir $(FILLED)) $(dir $(DST)) "$(ARTIFACTS)"

# --------------------- Update pipeline (placed first) ----------------

update: ## Update submodules and regenerate artifacts from RAW
> $(TRACE) echo "[UPDATE] git submodule update --recursive --remote"; \
> git submodule update --recursive --remote
> $(TRACE) mkdir -p "$(ARTIFACTS)" "$(dir $(INPUT_JSON))" "$(dir $(PARALLEL))" "$(dir $(BYDAY))"
> $(TRACE) echo "[RUN] $(SCRIPT_EXTRACT_FULL) $(RAW) -> $(INPUT_JSON)"; \
> bash "$(SCRIPT_EXTRACT_FULL)" $(FULL_ARGS) "$(RAW)" "$(INPUT_JSON)"
> $(TRACE) src="tosa-zh.json"; [ -f "$$src" ] || src="tosa.zh.json"; [ -f "$$src" ] || src="$(INPUT_JSON)"; \
> echo "[RUN] $(SCRIPT_EXTRACT_PARALLEL) $$src -> $(PARALLEL)"; \
> bash "$(SCRIPT_EXTRACT_PARALLEL)" $(PAR_ARGS) "$$src" "$(PARALLEL)"
> $(TRACE) echo "[RUN] $(SCRIPT_EXTRACT_BY_DAYS) $(INPUT_JSON) -> $(BYDAY)"; \
> if [ -f "$(SCRIPT_EXTRACT_BY_DAYS)" ]; then \
>   bash "$(SCRIPT_EXTRACT_BY_DAYS)" $(BY_DAYS_ARGS) "$(INPUT_JSON)" "$(BYDAY)"; \
> else \
>   echo "[ERROR] Day-split script not found: $(SCRIPT_EXTRACT_BY_DAYS)"; exit 1; \
> fi
> echo "[DONE] update pipeline finished"

# --------------------- RAW → artifacts pipeline ----------------------

raw-full: $(INPUT_JSON) ## Generate $(INPUT_JSON) from RAW
$(INPUT_JSON): $(RAW) $(SCRIPT_EXTRACT_FULL) | dirs
> $(TRACE) echo "[RAW→FULL] $(RAW) -> $@"; \
> bash "$(SCRIPT_EXTRACT_FULL)" $(FULL_ARGS) "$(RAW)" "$@"

raw-by-days: $(BYDAY) ## Generate BYDAY from INPUT_JSON
$(BYDAY): $(SCRIPT_EXTRACT_BY_DAYS) $(INPUT_JSON) | dirs
> $(TRACE) echo "[RAW→BY-DAYS] $(INPUT_JSON) -> $@"; \
> if [ -f "$(SCRIPT_EXTRACT_BY_DAYS)" ]; then \
>   bash "$(SCRIPT_EXTRACT_BY_DAYS)" $(BY_DAYS_ARGS) "$(INPUT_JSON)" "$@"; \
> else \
>   echo "[ERROR] Day-split script not found: $(SCRIPT_EXTRACT_BY_DAYS)"; exit 1; \
> fi

raw-parallel: $(PARALLEL) ## Generate PARALLEL from tosa-zh.json/tosa.zh.json or $(INPUT_JSON)
$(PARALLEL): $(SCRIPT_EXTRACT_PARALLEL) | dirs
> $(TRACE) src="tosa-zh.json"; \
> [ -f "$$src" ] || src="tosa.zh.json"; \
> [ -f "$$src" ] || src="$(INPUT_JSON)"; \
> echo "[RAW→PARALLEL] $$src -> $@"; \
> bash "$(SCRIPT_EXTRACT_PARALLEL)" $(PAR_ARGS) "$$src" "$@"

raw-all: raw-full raw-parallel raw-by-days ## Run all RAW → artifacts extractors

# --------------------- Glossary pipeline -----------------------------

glossary: $(OUT) ## Generate global glossary to $(OUT)
$(OUT): $(INPUT) $(ZISK) | dirs
> $(TRACE) tmp="$$(mktemp)"; \
>   echo "[GEN] $(INPUT) + $(ZISK) -> $@"; \
>   $(GEN) "$(INPUT)" "$(ZISK)" > "$$tmp"; \
>   mv -f "$$tmp" "$@"

fill: $(FILLED) ## Fill per-paragraph glossary-abbreviations using $(GLOSSARY)
$(FILLED): $(INPUT) $(GLOSSARY) | dirs
> $(TRACE) tmp="$$(mktemp)"; \
>   echo "[FILL] $(INPUT) + $(GLOSSARY) -> $@"; \
>   if [ ! -f "$(GLOSSARY)" ]; then echo "[ERROR] Glossary not found: $(GLOSSARY)"; exit 1; fi; \
>   $(FILL) "$(INPUT)" "$(GLOSSARY)" > "$$tmp"; \
>   mv -f "$$tmp" "$@"

stage: ## Copy edited glossary to $(DST)
> $(TRACE) test -f "$(EDITED)"
> $(TRACE) mkdir -p "$(dir $(DST))"
> $(TRACE) cp -f "$(EDITED)" "$(DST)"
> echo "[STAGE] $(EDITED) -> $(DST)"

activate: ## Symlink build/glossary.active.json -> EDITED
> $(TRACE) mkdir -p build
> $(TRACE) ln -sfn "$(abspath $(EDITED))" build/glossary.active.json
> echo "[ACTIVATE] build/glossary.active.json -> $(EDITED)"

publish: glossary fill ## Copy auto-generated results into artifacts/
> $(TRACE) mkdir -p "$(ARTIFACTS)"
> install -m 0644 "$(OUT)"    "$(ARTIFACTS)/glossary.json"
> install -m 0644 "$(FILLED)" "$(ARTIFACTS)/out.json"
> echo "[PUBLISH] $(OUT) -> $(ARTIFACTS)/glossary.json"
> echo "[PUBLISH] $(FILLED) -> $(ARTIFACTS)/out.json"

publish-edited: ## Copy your edited glossary into artifacts/
> $(TRACE) mkdir -p "$(ARTIFACTS)"
> $(TRACE) test -f "$(EDITED)" || { echo "[ERROR] EDITED not found: $(EDITED)"; exit 1; }
> install -m 0644 "$(EDITED)" "$(ARTIFACTS)/glossary.json"
> echo "[PUBLISH] $(EDITED) -> $(ARTIFACTS)/glossary.json"

publish-clean: ## Remove published files
> $(TRACE) rm -f "$(ARTIFACTS)/glossary.json" "$(ARTIFACTS)/out.json"
> rmdir --ignore-fail-on-non-empty "$(ARTIFACTS)" 2>/dev/null || true

# --------------------- Cleanup & diagnostics -------------------------

clean: ## Remove generated glossary pipeline files
> $(TRACE) rm -f "$(OUT)" "$(FILLED)" build/glossary.active.json
> echo "[CLEAN] removed glossary pipeline files"

clean-raw: ## Remove RAW → artifacts generated files
> $(TRACE) rm -f "$(INPUT_JSON)" "$(PARALLEL)" "$(BYDAY)"
> echo "[CLEAN] removed RAW artifacts"

print: ## Print current variables
> echo INPUT=$(INPUT)
> echo ZISK=$(ZISK)
> echo OUT=$(OUT)
> echo EDITED=$(EDITED)
> echo GLOSSARY=$(GLOSSARY)
> echo FILLED=$(FILLED)
> echo DST=$(DST)
> echo ARTIFACTS=$(ARTIFACTS)
> echo RAW=$(RAW)
> echo INPUT_JSON=$(INPUT_JSON)
> echo PARALLEL=$(PARALLEL)
> echo BYDAY=$(BYDAY)
> echo SCRIPTS_DIR=$(SCRIPTS_DIR)
> echo SCRIPT_EXTRACT_FULL=$(SCRIPT_EXTRACT_FULL)
> echo SCRIPT_EXTRACT_PARALLEL=$(SCRIPT_EXTRACT_PARALLEL)
> echo SCRIPT_EXTRACT_BY_DAYS=$(SCRIPT_EXTRACT_BY_DAYS)
> echo FULL_ARGS=$(FULL_ARGS)
> echo BY_DAYS_ARGS=$(BY_DAYS_ARGS)
> echo PAR_ARGS=$(PAR_ARGS)
