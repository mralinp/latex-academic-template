# =============================================================================
# LaTeX Academic Template -- Dockerized build system
#
# Everything compiles inside the texlive/texlive Docker image declared in
# docker-compose.yml. No local LaTeX installation is required -- only
# Docker and GNU Make.
#
# Quick start:
#   make list                        # see available templates
#   make build TEMPLATE=resume       # compile templates/resume/main.tex
#   make help                        # see all targets
# =============================================================================

SHELL := /bin/bash
COMPOSE := docker compose
SERVICE := latex
TEMPLATES_DIR := templates
DOCUMENTS_DIR := documents

TEMPLATE_NAMES := $(notdir $(patsubst %/,%,$(dir $(wildcard $(TEMPLATES_DIR)/*/main.tex))))

# When TEMPLATE=<name> is passed on the command line, pull in that template's
# own config (ENGINE, MAIN, SHELL_ESCAPE, ...) so the rest of this file can
# use it. Command-line variables (e.g. `make build TEMPLATE=x ENGINE=xelatex`)
# still take precedence over whatever a config.mk sets, per normal Make rules.
-include $(TEMPLATES_DIR)/$(TEMPLATE)/config.mk

ENGINE ?= pdflatex
MAIN ?= main.tex
SHELL_ESCAPE ?= false

ENGINE_FLAG := -pdf
ifeq ($(ENGINE),xelatex)
ENGINE_FLAG := -xelatex
endif
ifeq ($(ENGINE),lualatex)
ENGINE_FLAG := -lualatex
endif

SHELL_ESCAPE_FLAG :=
ifeq ($(SHELL_ESCAPE),true)
SHELL_ESCAPE_FLAG := -shell-escape
endif

LATEXMK_FLAGS := $(ENGINE_FLAG) -interaction=nonstopmode -halt-on-error -file-line-error -synctex=1 $(SHELL_ESCAPE_FLAG)

.PHONY: help list pull require-template build build-all compile watch new add-template \
        clean clean-all shell lint wordcount pages

.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "LaTeX Academic Template -- available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

list: ## List all available templates
	@for t in $(TEMPLATE_NAMES); do \
		desc=$$(grep -E '^DESCRIPTION[[:space:]]*:?=' $(TEMPLATES_DIR)/$$t/config.mk 2>/dev/null | sed -E 's/^DESCRIPTION[[:space:]]*:?=[[:space:]]*//'); \
		printf "  \033[36m%-20s\033[0m %s\n" "$$t" "$$desc"; \
	done

pull: ## Pull/update the LaTeX Docker image
	$(COMPOSE) pull

# Aborts the build (at parse time, before any container runs) if TEMPLATE is
# missing or unknown. Used as a prerequisite by targets that need TEMPLATE.
require-template:
ifndef TEMPLATE
	$(error TEMPLATE is required. Run 'make list' to see available templates, e.g. make build TEMPLATE=resume)
endif
ifeq (,$(wildcard $(TEMPLATES_DIR)/$(TEMPLATE)/$(MAIN)))
	$(error No such template '$(TEMPLATE)' (expected $(TEMPLATES_DIR)/$(TEMPLATE)/$(MAIN)) -- run 'make list' to see available templates)
endif

build: require-template ## Compile a template: make build TEMPLATE=resume [ENGINE=xelatex]
	$(COMPOSE) run --rm -w /work/$(TEMPLATES_DIR)/$(TEMPLATE) $(SERVICE) \
		latexmk $(LATEXMK_FLAGS) $(MAIN)

build-all: ## Compile every template under templates/
	@for t in $(TEMPLATE_NAMES); do \
		echo "==> Building $$t"; \
		$(MAKE) build TEMPLATE=$$t || exit 1; \
	done

compile: ## Compile any .tex file directly: make compile FILE=documents/my-paper/main.tex [ENGINE=xelatex]
ifndef FILE
	$(error FILE is required, e.g. make compile FILE=documents/my-paper/main.tex)
endif
	$(COMPOSE) run --rm -w /work/$(dir $(FILE)) $(SERVICE) \
		latexmk $(LATEXMK_FLAGS) $(notdir $(FILE))

watch: require-template ## Recompile a template on every save: make watch TEMPLATE=resume
	$(COMPOSE) run --rm -w /work/$(TEMPLATES_DIR)/$(TEMPLATE) $(SERVICE) \
		latexmk $(LATEXMK_FLAGS) -pvc $(MAIN)

new: ## Start a real document from a template: make new NAME=my-cv TEMPLATE=resume
ifndef NAME
	$(error NAME is required, e.g. make new NAME=my-cv TEMPLATE=resume)
endif
ifndef TEMPLATE
	$(error TEMPLATE is required, e.g. make new NAME=my-cv TEMPLATE=resume)
endif
	@dest="$(DOCUMENTS_DIR)/$(NAME)"; \
	if [ -e "$$dest" ]; then echo "'$$dest' already exists"; exit 1; fi; \
	if [ ! -d "$(TEMPLATES_DIR)/$(TEMPLATE)" ]; then echo "No such template '$(TEMPLATE)' -- run 'make list'"; exit 1; fi; \
	mkdir -p "$(DOCUMENTS_DIR)"; \
	cp -R "$(TEMPLATES_DIR)/$(TEMPLATE)" "$$dest"; \
	rm -f "$$dest/config.mk"; \
	echo "Created $$dest from template '$(TEMPLATE)'."; \
	echo "Build it with: make compile FILE=$$dest/main.tex"

add-template: ## Scaffold a new template: make add-template NAME=ieee-conference
ifndef NAME
	$(error NAME is required, e.g. make add-template NAME=ieee-conference)
endif
	@dest="$(TEMPLATES_DIR)/$(NAME)"; \
	if [ -e "$$dest" ]; then echo "Template '$(NAME)' already exists"; exit 1; fi; \
	mkdir -p "$$dest"; \
	printf '%s\n' \
		'\documentclass{article}' \
		'' \
		'\title{$(NAME)}' \
		'\author{}' \
		'\date{}' \
		'' \
		'\begin{document}' \
		'' \
		'\maketitle' \
		'' \
		'\end{document}' \
		> "$$dest/main.tex"; \
	printf '%s\n' \
		'NAME := $(NAME)' \
		'DESCRIPTION := Describe this template here.' \
		'TAGS :=' \
		'ENGINE := pdflatex' \
		'MAIN := main.tex' \
		'SHELL_ESCAPE := false' \
		> "$$dest/config.mk"; \
	echo "Created new template at $$dest -- edit $$dest/main.tex and $$dest/config.mk"

clean: require-template ## Remove build artifacts for one template: make clean TEMPLATE=resume
	$(COMPOSE) run --rm -w /work/$(TEMPLATES_DIR)/$(TEMPLATE) $(SERVICE) \
		latexmk -C $(MAIN)

clean-all: ## Remove build artifacts for every template and document
	@for t in $(TEMPLATE_NAMES); do \
		echo "==> Cleaning $$t"; \
		$(COMPOSE) run --rm -w /work/$(TEMPLATES_DIR)/$$t $(SERVICE) latexmk -C main.tex >/dev/null 2>&1 || true; \
	done
	@if [ -d "$(DOCUMENTS_DIR)" ]; then \
		for d in $(DOCUMENTS_DIR)/*/; do \
			[ -f "$${d}main.tex" ] || continue; \
			echo "==> Cleaning $$d"; \
			$(COMPOSE) run --rm -w /work/$$d $(SERVICE) latexmk -C main.tex >/dev/null 2>&1 || true; \
		done; \
	fi

shell: ## Open a shell in the LaTeX container: make shell [TEMPLATE=resume]
	$(COMPOSE) run --rm -w /work/$(if $(TEMPLATE),$(TEMPLATES_DIR)/$(TEMPLATE),.) $(SERVICE) bash

lint: require-template ## Lint a template with chktex: make lint TEMPLATE=resume
	$(COMPOSE) run --rm -w /work/$(TEMPLATES_DIR)/$(TEMPLATE) $(SERVICE) \
		chktex $(MAIN)

wordcount: require-template ## Word count a template with texcount: make wordcount TEMPLATE=resume
	$(COMPOSE) run --rm -w /work/$(TEMPLATES_DIR)/$(TEMPLATE) $(SERVICE) \
		texcount -inc $(MAIN)

pages: build-all ## Build the GitHub Pages preview site locally into ./site
	python3 scripts/build_pages.py
