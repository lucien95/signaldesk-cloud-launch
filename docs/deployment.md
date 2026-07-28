# Production-style deployment guide

This guide separates the one-time trust bootstrap from repeatable delivery.
Run commands from the repository root. Read the plan before every apply.

## 1. Verify the local operator

The bootstrap operator is a human project owner. Application Default
Credentials let Terraform use that identity without placing a credential in
the repository. The development provider also explicitly attributes quota and
billing API requests to the managed project; this avoids depending on whichever
project a workstation credential originally came from.

```bash
gcloud config get-value account
gcloud config get-value project
gcloud auth application-default set-quota-project kloudwithlucien-503200
```

Expected account: the owning Google account. Expected project:
`kloudwithlucien-503200`.

## 2. Validate the trust root locally

`terraform/bootstrap/terraform.tfvars` is intentionally ignored by Git. Review
it, then run:

```bash
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap fmt -check
terraform -chdir=terraform/bootstrap validate
terraform -chdir=terraform/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=terraform/bootstrap show -json bootstrap.tfplan \
  > /tmp/signaldesk-bootstrap-plan.json
make opa-eval PLAN_JSON=/tmp/signaldesk-bootstrap-plan.json
```

The expected initial summary is additions only, with no changes or deletions.
`bootstrap.tfplan` is a binary plan: applying that file prevents a surprise
re-plan between review and execution.

Use the Terraform version pinned in GitHub Actions when reproducing delivery
plans locally. Older valid Terraform releases can decode provider state
differently and are not the authoritative release toolchain.

## 3. Apply once, then migrate bootstrap state

Only after reviewing the plan:

```bash
terraform -chdir=terraform/bootstrap apply bootstrap.tfplan
cp terraform/bootstrap/backend.gcs.tf.example terraform/bootstrap/backend.tf
terraform -chdir=terraform/bootstrap init -migrate-state \
  -backend-config="bucket=kloudwithlucien-503200-signaldesk-tfstate" \
  -backend-config="prefix=signaldesk/bootstrap"
```

Terraform will ask whether to copy the local state. Read the prompt and answer
`yes`. Verify:

```bash
terraform -chdir=terraform/bootstrap state list
terraform -chdir=terraform/bootstrap output
```

Why this sequence exists: the bucket cannot store bootstrap state until
bootstrap creates the bucket. Migration closes that temporary local-state
window immediately after creation. Commit `terraform/bootstrap/backend.tf`
after a successful migration so later checkouts use the remote backend.

## 4. Create GitHub environments

In GitHub, open **Settings → Environments** and create:

1. `infrastructure-plan` — no reviewer. It creates the proposal but cannot
   bypass the apply environment.
2. `infrastructure-development` — add a required reviewer or wait timer. This
   is the human approval between plan and apply.
3. `development` — the application release environment. Approval is optional
   for continuous delivery to this lab environment.

The names are security controls: GCP's OIDC conditions require these exact
environment claims.

## 5. Configure non-secret GitHub variables

Open **Settings → Secrets and variables → Actions → Variables**. Add these at
repository scope so every protected environment inherits one consistent value:

| Variable | Value source |
|---|---|
| `GCP_PROJECT_ID` | `kloudwithlucien-503200` |
| `GCP_BILLING_ACCOUNT_ID` | billing account attached to the project |
| `GCP_REGION` | `us-east1` |
| `TF_STATE_BUCKET` | bootstrap output `state_bucket` |
| `GCP_INFRA_WORKLOAD_IDENTITY_PROVIDER` | bootstrap output `infrastructure_workload_identity_provider` |
| `GCP_INFRA_SERVICE_ACCOUNT` | bootstrap output `infrastructure_deploy_service_account` |
| `GCP_APP_WORKLOAD_IDENTITY_PROVIDER` | bootstrap output `application_workload_identity_provider` |
| `GCP_APP_DEPLOY_SERVICE_ACCOUNT` | bootstrap output `application_deploy_service_account` |
| `GCP_ARTIFACT_REPOSITORY` | `signaldesk` |
| `GCP_CLOUD_RUN_SERVICE` | `signaldesk-dev` |

These are identifiers, not secrets. Do not duplicate them inside individual
GitHub environments because environment-level values override repository values
and can drift. Authentication comes from a short-lived OIDC exchange; do not
create or upload a service-account JSON key.

New Workload Identity configuration can take a few minutes to propagate. If the
first correctly configured authentication attempt is denied, wait five minutes
and retry before changing IAM.

## 6. Protect `main`

Create a GitHub ruleset for `main`:

- require a pull request and, when a second trusted reviewer is available,
  CODEOWNER approval;
- dismiss stale approvals;
- require conversation resolution;
- block force pushes and branch deletion;
- require the application, Terraform, and DevSecOps jobs after their first pull
  request run establishes the check names.

Dependabot proposes pinned action, Python, Docker, and Terraform updates as
pull requests so upgrades pass the same gates.

For a solo portfolio repository, do not create an impossible self-approval
rule. Require the checks and use the protected infrastructure environment's
wait timer, or invite a second trusted reviewer. In a client repository,
separation of duties should use a reviewer other than the change author.

## 7. Merge and follow the delivery

Pull requests run quality and security checks without cloud write credentials.
After merge, `.github/workflows/delivery.yml`:

1. repeats all quality gates on the trusted `main` commit;
2. detects whether application or development infrastructure changed;
3. exchanges GitHub OIDC for a short-lived infrastructure credential;
4. creates a binary Terraform plan and evaluates its JSON with OPA;
5. hashes the plan and stores both files in the protected state bucket;
6. pauses at `infrastructure-development` for approval;
7. downloads, checksum-verifies, and applies that exact plan;
8. builds and scans the application image, creates an SBOM, and pushes it;
9. deploys by immutable digest with no traffic;
10. smoke-tests the candidate, promotes it, and verifies the public service.

Bootstrap itself never runs automatically. A compromised application change
therefore cannot silently rewrite the GitHub-to-GCP trust relationship.

## 8. Verify the result

```bash
gcloud run services describe signaldesk-dev \
  --project kloudwithlucien-503200 \
  --region us-east1 \
  --format='value(status.url)'
```

Test `/health/live`, `/health/ready`, and one booking request. Then capture the
evidence listed in `docs/acceptance-criteria.md`.
