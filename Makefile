PYTHON := .venv/bin/python

.PHONY: install test lint run docker-build up down terraform-check

.venv/bin/python:
	python3 -m venv .venv

install: .venv/bin/python
	$(PYTHON) -m pip install -r app/requirements-dev.txt

test:
	DATABASE_URL=sqlite+pysqlite:///:memory: $(PYTHON) -m pytest -q

lint:
	$(PYTHON) -m ruff check app
	$(PYTHON) -m bandit -q -r app/signaldesk

run:
	PYTHONPATH=app $(PYTHON) -m uvicorn signaldesk.main:app --reload --host 0.0.0.0 --port 8080

docker-build:
	docker build -t signaldesk-api:local app

up:
	docker compose up --build

down:
	docker compose down

terraform-check:
	terraform -chdir=terraform/bootstrap fmt -check -recursive
	terraform -chdir=terraform/environments/dev fmt -check -recursive
	terraform -chdir=terraform/bootstrap init -backend=false
	terraform -chdir=terraform/bootstrap validate
	terraform -chdir=terraform/environments/dev init -backend=false
	terraform -chdir=terraform/environments/dev validate
