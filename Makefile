PYTHON := .venv/bin/python
SECURITY_PYTHON := .security-venv/bin/python
OPA := .tools/bin/opa
TRIVY := .tools/bin/trivy
ACTIONLINT := .tools/bin/actionlint

.PHONY: install frontend-install frontend-check frontend-e2e test lint run docker-build up down terraform-check security-install dependency-audit actionlint-install actionlint checkov opa-install opa-test opa-eval trivy-install trivy-fs trivy-image security-check

.venv/bin/python:
	python3 -m venv .venv

install: .venv/bin/python
	$(PYTHON) -m pip install -r app/requirements-dev.txt

frontend-install:
	npm ci --prefix app/frontend

frontend-check: frontend-install
	npm --prefix app/frontend run lint
	npm --prefix app/frontend run test
	npm --prefix app/frontend run build

frontend-e2e: install frontend-check
	cd app/frontend && npx playwright install chromium
	PYTHON_BIN=$(abspath $(PYTHON)) npm --prefix app/frontend run test:e2e

.security-venv/bin/python:
	python3 -m venv .security-venv

security-install: .security-venv/bin/python
	$(SECURITY_PYTHON) -m pip install -r security/requirements.txt

dependency-audit: security-install
	$(SECURITY_PYTHON) -m pip_audit -r app/requirements.txt

actionlint-install:
	./scripts/install-actionlint.sh

actionlint: actionlint-install
	$(ACTIONLINT) -color

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

checkov: security-install
	.security-venv/bin/checkov --config-file .checkov.yml

opa-install:
	./scripts/install-opa.sh

opa-test: opa-install
	$(OPA) fmt --fail --diff policy/terraform
	$(OPA) test policy/terraform --fail-on-empty -v

opa-eval: opa-install
	@test -n "$(PLAN_JSON)" || (echo "Set PLAN_JSON to a Terraform plan JSON file" && exit 1)
	./scripts/evaluate-terraform-policy.sh "$(PLAN_JSON)"

trivy-install:
	./scripts/install-trivy.sh

trivy-fs: trivy-install
	$(TRIVY) fs --scanners vuln,secret,misconfig --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --skip-dirs .git --skip-dirs .terraform --skip-dirs .venv --skip-dirs .security-venv --skip-dirs .tools --skip-files "**/*.tfstate*" .

trivy-image: trivy-install docker-build
	$(TRIVY) image --scanners vuln,secret --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 signaldesk-api:local

security-check: dependency-audit actionlint checkov opa-test trivy-fs
