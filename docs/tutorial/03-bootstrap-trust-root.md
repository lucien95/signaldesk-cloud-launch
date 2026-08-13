# 03 — Bootstrap the trust root once

## Outcome

Terraform creates the protected remote-state bucket, two Workload Identity
Federation (WIF) trust paths, and separate infrastructure/application deployer
service accounts. Bootstrap state is then moved from the temporary local file
into GCS.

## Business reason

Automation cannot safely manage a cloud environment until it has an identity
and a protected place for Terraform state. Bootstrap establishes those roots
under deliberate human control. Keeping it outside normal CI reduces the chance
that an application change can rewrite the mechanism that authenticates CI.

## Concepts

Bootstrap is a chicken-and-egg sequence:

```text
Human owner + ADC
        |
        v
Local bootstrap plan and policy review
        |
        v
State bucket + WIF providers + deploy service accounts
        |
        v
Migrate bootstrap state from local disk to GCS
        |
        v
GitHub can be configured with bootstrap outputs
```

The bootstrap `google_project_service` loop enables APIs required to establish
IAM, federation, token exchange, and Cloud Storage. `for_each` creates one API
activation resource per service. `disable_on_destroy = false` deliberately
prevents a later Terraform destroy from disabling shared project APIs.

## Before you run anything

- Chapter 02 must pass.
- Billing must be enabled.
- The GitHub repository must already exist because its immutable numeric IDs
  are inputs to the trust condition.
- Choose a globally unique state bucket name.
- Confirm this is a new bootstrap. If resources/state already exist, inspect
  and import/reconcile them; do not apply an “initial” plan over them.

Set the local context:

```bash
export PROJECT_ID="kloudwithlucien-503200"
export REPOSITORY="lucien95/signaldesk-cloud-launch"
export STATE_BUCKET="${PROJECT_ID}-signaldesk-tfstate"
```

## Implementation

### 1. Collect immutable GitHub identifiers

```bash
gh api "repos/${REPOSITORY}" --jq '{full_name,id,owner_id:.owner.id,default_branch}'
```

Repository and owner IDs remain stable across renames and are stronger trust
inputs than names alone.

### 2. Prepare the ignored variable file

```bash
cp terraform/bootstrap/terraform.tfvars.example \
  terraform/bootstrap/terraform.tfvars
```

Edit `terraform/bootstrap/terraform.tfvars` and set:

- project ID and region;
- `lucien95/signaldesk-cloud-launch` or the reader's fork;
- numeric repository and owner IDs from `gh api`;
- `main` and the two exact workflow paths;
- the real billing-account ID;
- the globally unique state bucket name.

The billing-account ID is needed because normal Terraform later creates the
project budget. The file is ignored by Git. Confirm before continuing:

```bash
git check-ignore terraform/bootstrap/terraform.tfvars
```

### 3. Initialize without a backend and review one exact plan

The GCS backend declaration already exists, but the bucket does not. Disable it
for the first initialization:

```bash
terraform -chdir=terraform/bootstrap init -backend=false
terraform -chdir=terraform/bootstrap fmt -check
terraform -chdir=terraform/bootstrap validate
terraform -chdir=terraform/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=terraform/bootstrap show -json bootstrap.tfplan \
  > /tmp/signaldesk-bootstrap-plan.json
make opa-eval PLAN_JSON=/tmp/signaldesk-bootstrap-plan.json
```

Read the resource actions and summary. On a new project, expect additions and
no destructive changes. Do not publish raw plan JSON: it contains much more
metadata than the summary needed for evidence.

### 4. Apply the reviewed binary plan once

```bash
terraform -chdir=terraform/bootstrap apply bootstrap.tfplan
```

Applying the saved binary file ensures Terraform does not silently create a
different proposal after review.

### 5. Migrate bootstrap state immediately

```bash
terraform -chdir=terraform/bootstrap init -migrate-state \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="prefix=signaldesk/bootstrap"
```

Read the prompt and approve copying local state only after confirming the
bucket name. Then verify:

```bash
terraform -chdir=terraform/bootstrap state list
terraform -chdir=terraform/bootstrap output
gcloud storage buckets describe "gs://${STATE_BUCKET}" \
  --format='yaml(name,location,iamConfiguration.uniformBucketLevelAccess.enabled,iamConfiguration.publicAccessPrevention,versioning.enabled)'
```

Remove temporary local plan evidence after review:

```bash
rm -f terraform/bootstrap/bootstrap.tfplan \
  /tmp/signaldesk-bootstrap-plan.json
```

Never delete the remote state object as cleanup.

## Expected result

- The state bucket has versioning, uniform bucket-level access, and public
  access prevention.
- Pools `signaldesk-infra` and `signaldesk-app` and their `github` providers
  exist.
- The two deployer service accounts exist.
- Terraform outputs the bucket, providers, and account email identifiers needed
  in Chapter 04.
- Bootstrap state now uses `signaldesk/bootstrap` in GCS.

## Screenshot checkpoints

- **SD-03-01** — only the reviewed plan summary plus a successful OPA result.
- **SD-03-02** — bucket versioning, uniform access, and public-access prevention.
- **SD-03-03** — formatted Terraform output identifiers.

Crop the billing account and never open a `.tfstate` object or raw plan JSON for
a screenshot.

## Security and cost review

The state bucket is highly sensitive because state contains infrastructure
metadata and may contain sensitive values. Its object access belongs to the
infrastructure identity, not the application deployer. Service-account keys are
not created. Bucket storage and API calls are minimal, but versioning can retain
old objects, so access and lifecycle behavior still matter.

## Troubleshooting

- Backend bucket does not exist: the first init must use `-backend=false`.
- Bucket name conflict: choose a globally unique name and update the ignored
  variable file before planning again.
- WIF creation returns API errors: confirm `iam`, `iamcredentials`, and `sts`
  services were enabled; API propagation can take a few minutes.
- Migration sees no local state: stop and locate the actual state before
  continuing. Do not create an empty competing state.
- Existing-resource conflict: import/reconcile the resource rather than deleting
  it from the console.

## Explain it in an interview

> Bootstrap is a deliberate one-time local operation because the remote state
> bucket and CI trust do not exist yet. I used the owner through ADC to review
> and apply one saved plan, then migrated state to a versioned, non-public GCS
> backend. The bootstrap creates separate infrastructure and application WIF
> providers and deploy identities, and it is excluded from automatic main-branch
> delivery so routine releases cannot silently alter their own trust root.

## Completion gate

- [ ] I can explain why bootstrap cannot start with its own new GCS bucket.
- [ ] The plan was additions-only and the exact binary was applied.
- [ ] Bootstrap state is remote and the bucket controls were verified.
- [ ] I can identify all five safe Terraform outputs.
- [ ] No raw state, plan JSON, billing ID, or credential was captured.
- [ ] SD-03-01 through SD-03-03 are sanitized and recorded.

[Previous: 02 — GCP project, billing, and ADC](02-gcp-project-billing-and-adc.md) · [Next: 04 — Connect GitHub without keys](04-github-keyless-authentication.md)
