#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 PATH_TO_TERRAFORM_PLAN_JSON" >&2
  exit 2
fi

plan_json="$1"
opa_binary="${OPA_BINARY:-.tools/bin/opa}"

if [[ ! -f "${plan_json}" ]]; then
  echo "Terraform plan JSON not found: ${plan_json}" >&2
  exit 2
fi

if [[ ! -x "${opa_binary}" ]]; then
  echo "OPA not found at ${opa_binary}; run scripts/install-opa.sh first" >&2
  exit 2
fi

echo "SignalOps Terraform policy decisions:"
"${opa_binary}" eval \
  --strict \
  --strict-builtin-errors \
  --format pretty \
  --data policy/terraform \
  --input "${plan_json}" \
  'data.signalops.terraform.deny'

"${opa_binary}" eval \
  --strict \
  --strict-builtin-errors \
  --fail-defined \
  --format discard \
  --data policy/terraform \
  --input "${plan_json}" \
  'data.signalops.terraform.deny[_]'

echo "OPA policy gate passed"
