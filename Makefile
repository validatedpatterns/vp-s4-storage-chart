# https://hub.docker.com/r/helmunittest/helm-unittest/tags/
HELM_UNITTEST_IMAGE ?= docker.io/helmunittest/helm-unittest:3.14.4-0.5.0
HELM_DOCS_IMAGE ?= docker.io/jnorwood/helm-docs:latest

PWD=$(shell pwd)
MYNAME=$(shell id -n -u)
MYUID=$(shell id -u)
MYGID=$(shell id -g)
PODMAN_ARGS := --security-opt label=disable --net=host --rm --passwd-entry "$(MYNAME):x:$(MYUID):$(MYGID)::/apps:/bin/bash" --user $(MYUID):$(MYGID) --userns keep-id:uid=$(MYUID),gid=$(MYGID)
##@ Common Tasks

.PHONY: help
help: ## This help message
	@echo "Pattern: $(NAME)"
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^(\s|[a-zA-Z_0-9-])+:.*?##/ { printf "  \033[36m%-35s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

S4_CHART_REPO ?= https://github.com/rh-aiservices-bu/s4.git
S4_CHART_REF ?= main

.PHONY: helm-deps
helm-deps: ## Vendor the upstream s4 chart and download Helm dependencies
	@mkdir -p charts
	@if [ ! -f charts/s4/Chart.yaml ]; then \
		rm -rf /tmp/s4-chart-vendor; \
		git clone --depth 1 --branch $(S4_CHART_REF) $(S4_CHART_REPO) /tmp/s4-chart-vendor; \
		rm -rf charts/s4; \
		cp -a /tmp/s4-chart-vendor/charts/s4 charts/s4; \
		rm -rf /tmp/s4-chart-vendor; \
	fi
	helm dependency update .

.PHONY: helm-lint
helm-lint: helm-deps ## Runs helm lint against the chart
	helm lint .

.PHONY: helm-unittest
helm-unittest: helm-deps ## Runs the helm unit tests
	podman run $(PODMAN_ARGS) -v $(PWD):/apps:rw $(HELM_UNITTEST_IMAGE) .

.PHONY: helm-docs
helm-docs: ## Generates README.md from values.yaml
	# First make sure all values.yaml entries are documented. This can only be enabled once
	# https://www.github.com/norwoodj/helm-docs/issues/228 is fixed
	# podman run $(PODMAN_ARGS) -v $(PWD):/helm-docs:rw $(HELM_DOCS_IMAGE) -x
	# Then render the README.md file
	podman run $(PODMAN_ARGS) -v $(PWD):/helm-docs:rw $(HELM_DOCS_IMAGE)

.PHONY: test
test: helm-lint helm-unittest ## Runs helm lint and unit tests

.PHONY: super-linter
super-linter: ## Runs super linter locally
	rm -rf .mypy_cache
	podman run -e RUN_LOCAL=true -e USE_FIND_ALGORITHM=true	\
					-e VALIDATE_BIOME_FORMAT=false \
					-v $(PWD):/tmp/lint:rw,z \
					-w /tmp/lint \
					ghcr.io/super-linter/super-linter:slim-v8
