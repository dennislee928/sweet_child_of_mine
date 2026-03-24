SHELL := /bin/bash

OVERLAY ?= k8s/overlays/kind
PYTEST_VENV := .venv-test

.PHONY: help test lint build kind-up deploy smoke pre-commit yaml-lint clean

help:
	@echo "Targets: test lint build kind-up deploy smoke pre-commit yaml-lint clean"

test:
	python3 -m venv $(PYTEST_VENV)
	$(PYTEST_VENV)/bin/pip install -q -r apps/exchange-simulator/requirements.txt pytest
	$(PYTEST_VENV)/bin/pytest apps/exchange-simulator/tests -q

lint: pre-commit

build:
	docker build -t exchange-simulator:dev apps/exchange-simulator
	docker build -t eve-forwarder:dev apps/eve-forwarder
	docker build -t indexer-worker:dev apps/indexer-worker

kind-up:
	kind create cluster --name exchange-honeynet

deploy:
	OVERLAY=$(OVERLAY) bash scripts/deploy.sh

smoke:
	OVERLAY=$(OVERLAY) bash scripts/smoke.sh

yaml-lint:
	docker run --rm -v "$$(pwd):/work" cytopia/yamllint:latest -f parsable \
		.github/workflows k8s

pre-commit:
	python3 -m venv $(PYTEST_VENV)
	$(PYTEST_VENV)/bin/pip install -q ruff
	$(PYTEST_VENV)/bin/ruff check .
	$(PYTEST_VENV)/bin/ruff format --check .
	$(MAKE) yaml-lint

clean:
	rm -rf $(PYTEST_VENV)
