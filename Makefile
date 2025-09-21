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
# Paths (override via CLI or .env)
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
# Commands (flake apps; escape '#' so make does not treat it as a comment)
# --------------------------------------------------------------------
GEN  ?= nix run .\#generate-glossary --
FILL ?= nix run .\#fill-glossary --

# Load optional overrides
-include .env

# --------------------------------------------------------------------
# Phony targets
# --------------------------------------------------------------------
.PHONY: help dirs glossary fill stage activate fonts-cache publish publish-edited publish-clean clean print

help: ## Show help
> awk 'BEGIN{FS=":.*##"; printf "\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*##/{printf "  \033[1m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dirs: ## Create output directories
> $(TRACE) mkdir -p $(dir $(OUT)) $(dir $(FILLED)) $(dir $(DST)) "$(ARTIFACTS)"

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

fonts-cache: ## One-time font cache refresh (creates a stamp file)
> $(TRACE) if command -v fc-cache >/dev/null; then \
>   if [ ! -e .font-cache.stamp ]; then \
>     echo "[FONTS] Refreshing font cache..."; \
>     fc-cache -r >/dev/null 2>&1 || true; \
>     touch .font-cache.stamp; \
>   else \
>     echo "[FONTS] Cache already refreshed (stamp exists)"; \
>   fi \
> else \
>   echo "[FONTS] fc-cache not found (skipping)"; \
> fi

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

clean: ## Remove generated files
> $(TRACE) rm -f "$(OUT)" "$(FILLED)" build/glossary.active.json
> echo "[CLEAN] removed generated files"

print: ## Print current variables
> echo INPUT=$(INPUT)
> echo ZISK=$(ZISK)
> echo OUT=$(OUT)
> echo EDITED=$(EDITED)
> echo GLOSSARY=$(GLOSSARY)
> echo FILLED=$(FILLED)
> echo DST=$(DST)
> echo ARTIFACTS=$(ARTIFACTS)
