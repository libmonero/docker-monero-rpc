.DEFAULT_GOAL := help

VARIANT ?= default
NPROC ?=
PYTEST ?=
BUILD_ARGS = --build-arg VARIANT=$(VARIANT) $(if $(NPROC),--build-arg NPROC=$(NPROC))

.PHONY: help submodules update build test functional

help:
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "%-12s %s\n", $$1, $$2}'

submodules: ## Initialize the submodules
	./bin/update_submodules.sh

update: ## Move monero-project to a monero-cpp release, e.g. make update TAG=v0.9.10
	./bin/update_monero_rpc.sh $(TAG)

build: ## Build the images, e.g. make build VARIANT=private-testnet NPROC=1
	docker build --target monero-daemon-rpc $(BUILD_ARGS) -t monero-daemon-rpc:$(VARIANT) .
	docker build --target monero-wallet-rpc $(BUILD_ARGS) -t monero-wallet-rpc:$(VARIANT) .
	docker build --target monero-wallet-light $(BUILD_ARGS) -t monero-wallet-light:$(VARIANT) .

test: ## Run the pytest tests on the images of make build, e.g. make test PYTEST="tests/test_images.py -k daemon"
	./bin/pytest_tests.sh monero-daemon-rpc:$(VARIANT) monero-wallet-rpc:$(VARIANT) monero-wallet-light:$(VARIANT) $(VARIANT) $(PYTEST)

functional: ## Run the functional tests of monero-project on the images of make build, e.g. make functional TESTS="uri wallet"
	./bin/extract_binaries.sh build/binaries monero-daemon-rpc:$(VARIANT) monerod
	./bin/extract_binaries.sh build/binaries monero-wallet-rpc:$(VARIANT) monero-wallet-rpc
	./bin/functional_tests.sh build/binaries $(TESTS)
