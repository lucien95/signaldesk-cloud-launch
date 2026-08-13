# 05 — Build the environment through DevSecOps gates

## Outcome

A pull request validates the application and infrastructure, the trusted main
workflow proposes a real Terraform change, OPA evaluates that proposal, a human
boundary approves it, and the exact reviewed plan creates the runtime platform.

## Business reason

Small teams often need both speed and guardrails. Automated checks catch common
mistakes early, while exact-plan approval ensures the change discussed by a
human is the same artifact applied to the client environment.

## Concepts

The tools answer different questions:

| Tool | Input | Main question |
|---|---|---|
| Ruff/Bandit/pytest | Python | Is behavior correct and are common code risks absent? |
| pip-audit | Python dependencies | Are packages affected by known advisories? |
| actionlint | Workflow YAML | Are GitHub workflows structurally and semantically valid? |
| Checkov | Terraform, Dockerfile, workflows | Does source match broad secure-configuration checks? |
| OPA/Rego | Actual Terraform plan JSON | Does this proposed change obey SignalOps rules? |
| Trivy | Filesystem and built image | Are secrets, misconfigurations, or vulnerable shipped packages present? |

`terraform/bootstrap/` establishes trust once. `terraform/environments/dev/`
is the repeatable platform: APIs, network, private services access, database,
secret, Artifact Registry, runtime identity, Cloud Run, logging/monitoring, and
budget.

## Before you run anything

Chapter 04 must be complete. Prepare the ignored environment variables:

```bash
cp terraform/environments/dev/terraform.tfvars.example \
  terraform/environments/dev/terraform.tfvars
```

Set the project, region, deploy identities, billing account, USD 10 budget,
small database tier, max three Cloud Run instances, and intended public demo
flag. Confirm it remains ignored:

```bash
git check-ignore terraform/environments/dev/terraform.tfvars
```

The CI workflow receives equivalent values from GitHub repository variables;
it does not receive this local file.

## Implementation

### 1. Run the same classes of checks locally

```bash
make install
make lint
make test
make terraform-check
make security-check
make trivy-image
```

Review all Checkov exceptions inline beside their Terraform resource. A passing
count with hidden or unexplained skips is not acceptable evidence.

### 2. Inspect a real environment plan locally

```bash
export STATE_BUCKET="$(terraform -chdir=terraform/bootstrap output -raw state_bucket)"

terraform -chdir=terraform/environments/dev init \
  -input=false -lockfile=readonly \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="prefix=signaldesk/dev"

terraform -chdir=terraform/environments/dev plan \
  -lock-timeout=5m -out=/tmp/signaldesk-dev.tfplan

terraform -chdir=terraform/environments/dev show -json \
  /tmp/signaldesk-dev.tfplan > /tmp/signaldesk-dev-plan.json

make opa-eval PLAN_JSON=/tmp/signaldesk-dev-plan.json
shasum -a 256 /tmp/signaldesk-dev.tfplan
```

Read the changes, policy result, and cost-bearing resources. This is rehearsal;
the main workflow creates the authoritative delivery plan with Terraform 1.15.8.

### 3. Open a pull request

Create a focused branch, commit the reviewed source changes, and open a pull
request. Verify these check groups:

- application quality;
- Terraform format and validation;
- DevSecOps security gate;
- filesystem/container scan and SBOM where configured.

Pull-request jobs have `contents: read` and no GCP deployment credential. They
validate untrusted changes without granting cloud write access.

### 4. Merge and follow the protected infrastructure lane

After required checks pass and the pull request is reviewed, merge to `main`.
`.github/workflows/delivery.yml` then:

1. repeats quality checks on the trusted commit;
2. detects infrastructure/application paths;
3. requests a short-lived infrastructure credential;
4. initializes `signaldesk/dev` remote state;
5. creates `tfplan` and converts it to JSON;
6. evaluates the real plan with OPA;
7. hashes and stores the binary plan and checksum in protected GCS;
8. pauses at `infrastructure-development`;
9. downloads and checksum-verifies the artifact;
10. applies `terraform apply tfplan` and removes temporary plan objects.

Review the plan job before approving the environment. Do not approve solely
because the job is green.

### 5. Verify the runtime platform

After apply:

```bash
terraform -chdir=terraform/environments/dev output
terraform -chdir=terraform/environments/dev plan -detailed-exitcode
```

Exit code 0 means no drift; 2 means changes exist; 1 means an error. Inspect
Cloud SQL connections and confirm public IPv4 is disabled.

## Expected result

- All source and security gates pass with documented exceptions only.
- The plan artifact checksum is verified before apply.
- Terraform creates the desired services; the names added in GitHub Chapter 04
  now resolve to real Artifact Registry and Cloud Run resources.
- A follow-up plan reports no changes.
- Cloud SQL uses a private network and no public IPv4.

## Screenshot checkpoints

- **SD-05-01** — pull-request checks summary.
- **SD-05-02** — concise Checkov, OPA, and Trivy success evidence.
- **SD-05-03** — protected apply approval and its dependency on the plan job.
- **SD-05-04** — Cloud SQL connection page showing private networking and no
  public IP, with the private address cropped.

Do not publish raw plan JSON, state, workflow environment dumps, or discovered
secret-like fixtures.

## Security and cost review

OPA blocks protected-resource deletion, unsafe public exposure outside the
development exception, missing labels, and excessive Cloud Run scaling. Trivy
checks what ships; Checkov checks broad configuration source. The database is
the major recurring expense. Min-zero/max-three Cloud Run, a small zonal SQL
tier, capped disk growth, image cleanup, and a $10 budget bound the lab design.

## Troubleshooting

- A PR check name cannot yet be required: let it run once, then add the exact
  observed name to the ruleset.
- OPA denies a plan: read the denial and fix the proposed resource; do not
  disable the policy to obtain a green run.
- Plan/apply checksum fails: reject the run. The artifact is no longer the
  approved proposal.
- Apply cannot read state: verify the infrastructure provider output, service
  account, bucket variable, and `signaldesk/dev` prefix.
- Cloud SQL provisioning takes time: inspect the workflow step and GCP operation
  before rerunning; avoid concurrent applies.

## Explain it in an interview

> Pull requests run code, IaC, dependency, policy, secret, workflow, and image
> checks without cloud write credentials. On main, the infrastructure identity
> creates one binary Terraform plan against remote state. OPA evaluates its
> JSON, the pipeline hashes and stores the binary in protected GCS, and a
> protected environment approves the apply. The next job verifies SHA-256 and
> applies only that saved file. This prevents a post-approval re-plan from
> changing what reaches the client environment.

## Completion gate

- [ ] I can explain the distinct role of Checkov, OPA, and Trivy.
- [ ] PR checks pass without cloud deployment credentials.
- [ ] I reviewed and approved the actual planned resources and cost drivers.
- [ ] The exact plan checksum passed and the follow-up plan shows no drift.
- [ ] Cloud SQL has no public IPv4 address.
- [ ] SD-05-01 through SD-05-04 are sanitized and recorded.

[Previous: 04 — Connect GitHub without keys](04-github-keyless-authentication.md) · [Next: 06 — First safe release](06-first-safe-release.md)
