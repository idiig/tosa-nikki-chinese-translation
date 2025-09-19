# Makefile

# Use bash with strict flags for all recipes
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.RECIPEPREFIX := >

# Debug (set DEBUG=1 to enable command tracing)
DEBUG ?= 0
ifeq ($(DEBUG),1)
  TRACE := set -x;
else
  TRACE :=
endif

# Paths (override via CLI or .env)
INPUT    ?= data/tosa-zh.json
ZISK     ?= $(shell nix build --no-link --print-out-paths .\#zisk-conventions)
OUT      ?= build/glossary.json
FILLED   ?= build/out.json
EDITED   ?= data/glossary.edited.json
DST      ?= data/final/glossary.json

# Commands (flake apps; escape '#' so make does not treat it as a comment)
GEN  ?= nix run .\#generate-glossary --
FILL ?= nix run .\#fill-glossary --

-include .env

.PHONY: help dirs glossary fill stage activate fonts-cache clean print

help: ## Show help
> awk 'BEGIN{FS=":.*##"; printf "\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/{printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dirs: ## Create output directories
> $(TRACE) mkdir -p $(dir $(OUT)) $(dir $(FILLED)) $(dir $(DST))

glossary: $(OUT) ## Generate global glossary to $(OUT)
$(OUT): $(INPUT) $(ZISK) | dirs
> $(TRACE) tmp="$$(mktemp)"; \
>   echo "[GEN] $(INPUT) + $(ZISK) -> $@"; \
>   $(GEN) "$(INPUT)" "$(ZISK)" > "$$tmp"; \
>   mv -f "$$tmp" "$@"

fill: $(FILLED) ## Fill per-paragraph glossary-abbreviations using $(OUT)
$(FILLED): $(INPUT) $(OUT) | dirs
> $(TRACE) tmp="$$(mktemp)"; \
>   echo "[FILL] $(INPUT) + $(OUT) -> $@"; \
>   $(FILL) "$(INPUT)" "$(OUT)" > "$$tmp"; \
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

clean: ## Remove generated files
> $(TRACE) rm -f "$(OUT)" "$(FILLED)" build/glossary.active.json
> echo "[CLEAN] removed generated files"

print: ## Print current variables
> echo INPUT=$(INPUT)
> echo ZISK=$(ZISK)
> echo OUT=$(OUT)
> echo FILLED=$(FILLED)
> echo EDITED=$(EDITED)
> echo DST=$(DST)
