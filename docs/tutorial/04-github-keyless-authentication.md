# 04 — Connect GitHub to GCP without stored keys

## Outcome

GitHub has three correctly named environments, the required non-secret
variables, protected deployment boundaries, and permission to exchange a valid
job OIDC token for one short-lived GCP service-account credential.

## Business reason

Long-lived JSON keys are easy to copy, difficult to attribute, and require
rotation. Federation gives each eligible workflow job a short credential and
lets GCP reject tokens from the wrong repository, branch, workflow, or GitHub
environment.

## Concepts

Attribute mapping copies trusted claims from the GitHub token into attributes
GCP can use:

| GCP attribute | GitHub OIDC claim | Purpose |
|---|---|---|
| `google.subject` | `assertion.sub` | Unique workload subject |
| `attribute.repository_id` | `assertion.repository_id` | Immutable repository identity |
| `attribute.repository_owner_id` | `assertion.repository_owner_id` | Immutable owner identity |
| `attribute.ref` | `assertion.ref` | Exact branch reference |
| `attribute.workflow_ref` | `assertion.workflow_ref` | Calling delivery workflow and branch |
| `attribute.job_workflow_ref` | `assertion.job_workflow_ref` | Exact reusable application workflow |
| `attribute.environment` | `assertion.environment` | GitHub approval/environment boundary |

Mapping makes a claim available; it does not authorize it. The provider's CEL
condition checks exact allowed values. A service-account IAM binding then lets
the accepted principal set impersonate only its matching deployer account.

The infrastructure provider accepts `main`, the delivery workflow, immutable
repo/owner IDs, and only `infrastructure-plan` or
`infrastructure-development`. The application provider additionally requires
the reusable `deploy.yml` job workflow and only `development`.

## Before you run anything

Collect the bootstrap outputs without copying a screenshot of shell history:

```bash
export STATE_BUCKET="$(terraform -chdir=terraform/bootstrap output -raw state_bucket)"
export INFRA_PROVIDER="$(terraform -chdir=terraform/bootstrap output -raw infrastructure_workload_identity_provider)"
export INFRA_SA="$(terraform -chdir=terraform/bootstrap output -raw infrastructure_deploy_service_account)"
export APP_PROVIDER="$(terraform -chdir=terraform/bootstrap output -raw application_workload_identity_provider)"
export APP_SA="$(terraform -chdir=terraform/bootstrap output -raw application_deploy_service_account)"
```

## Implementation

### 1. Create exact GitHub environments

In the repository, open **Settings → Environments** and create:

1. `infrastructure-plan` — creates the proposal; no human approval required.
2. `infrastructure-development` — protects the exact-plan apply with a reviewer
   or wait timer.
3. `development` — protects application release; approval is optional for this
   development lab.

Names are case-sensitive security inputs because they appear in the OIDC token
and GCP provider conditions.

### 2. Configure repository Actions variables

Open **Settings → Secrets and variables → Actions → Variables** and add:

| Variable | Value |
|---|---|
| `GCP_PROJECT_ID` | `kloudwithlucien-503200` |
| `GCP_BILLING_ACCOUNT_ID` | The attached account ID; do not publish its value |
| `GCP_REGION` | `us-east1` |
| `TF_STATE_BUCKET` | `state_bucket` output |
| `GCP_INFRA_WORKLOAD_IDENTITY_PROVIDER` | Infrastructure provider output |
| `GCP_INFRA_SERVICE_ACCOUNT` | Infrastructure service-account output |
| `GCP_APP_WORKLOAD_IDENTITY_PROVIDER` | Application provider output |
| `GCP_APP_DEPLOY_SERVICE_ACCOUNT` | Application service-account output |
| `GCP_ARTIFACT_REPOSITORY` | `signaldesk` |
| `GCP_CLOUD_RUN_SERVICE` | `signaldesk-dev` |

The final two names are desired configuration inputs. Artifact Registry and
Cloud Run do not need to exist yet; Terraform creates them in Chapter 05 and
the application workflow later uses the same names to publish and deploy.

Keep these at repository scope so all three environments inherit one value.
Environment-level duplicates can override the repository value and drift.
Identifiers are not authentication secrets; authentication comes from OIDC.

### 3. Add environment protection

For `infrastructure-development`, add an available trusted reviewer or a wait
timer. In a solo portfolio repository, do not configure a reviewer rule that
the only contributor can never satisfy. In a client environment, the approver
should be a different trusted person from the change author.

Protect `main` using a repository ruleset:

- require a pull request;
- require status checks after their first PR run exposes their names;
- dismiss stale approvals and require conversation resolution;
- block force pushes and branch deletion;
- require CODEOWNER review when another trusted reviewer is available.

### 4. Inspect the GCP trust conditions

```bash
gcloud iam workload-identity-pools providers describe github \
  --project="${PROJECT_ID}" --location=global \
  --workload-identity-pool=signaldesk-infra \
  --format='yaml(attributeMapping,attributeCondition,oidc.issuerUri)'

gcloud iam workload-identity-pools providers describe github \
  --project="${PROJECT_ID}" --location=global \
  --workload-identity-pool=signaldesk-app \
  --format='yaml(attributeMapping,attributeCondition,oidc.issuerUri)'
```

Prove no downloadable CI keys exist:

```bash
for service_account in "${INFRA_SA}" "${APP_SA}"; do
  gcloud iam service-accounts keys list \
    --iam-account="${service_account}" --managed-by=user \
    --format='table(name.basename(),validAfterTime,validBeforeTime)'
done
```

## Expected result

- GitHub displays three exact environments and ten repository variables.
- GCP provider mappings and conditions match the code in
  `terraform/bootstrap/main.tf`.
- Both CI identities have zero user-managed keys.
- A job still needs `id-token: write`; that permission only allows requesting a
  token and does not itself grant GCP access.

## Screenshot checkpoints

- **SD-04-01** — GitHub environment list.
- **SD-04-02** — Actions variable **names** and safe values; crop the billing
  value and never open Secrets.
- **SD-04-03** — WIF mapping and CEL condition.
- **SD-04-04** — zero-row user-managed-key results for both accounts.

## Security and cost review

The two pools and service accounts separate infrastructure and application
blast radii. The application deployer can write images and update Cloud Run but
cannot manage Terraform state, networking, Cloud SQL, or the WIF trust root.
Federation and IAM metadata have negligible direct cost.

## Troubleshooting

- OIDC returns `unauthorized_client`: compare repository/owner numeric IDs,
  branch, workflow paths, and environment name character for character.
- Correct new federation is denied: wait several minutes for IAM propagation,
  then rerun before changing policy.
- `assertion.environment` is absent: the job must declare a matching GitHub
  `environment`.
- Reusable deploy workflow is rejected: confirm both `workflow_ref` and
  `job_workflow_ref` conditions match the calling and called files.
- GitHub asks for a JSON key: stop; this design does not use one.

## Explain it in an interview

> GitHub mints a signed OIDC token only for a job with `id-token: write`. GCP
> maps its claims, validates immutable repository and owner IDs plus branch,
> workflow, reusable workflow, and environment conditions, and permits that
> principal to impersonate one service account briefly. I separated app and
> infrastructure pools so an app delivery token cannot cross into the
> infrastructure trust path. No downloadable CI service-account keys exist.

## Completion gate

- [ ] I can distinguish attribute mapping, attribute condition, and IAM binding.
- [ ] All three exact GitHub environments exist.
- [ ] All ten repository variables come from understood sources.
- [ ] Both CI service accounts have zero user-managed keys.
- [ ] SD-04-01 through SD-04-04 are sanitized and recorded.

[Previous: 03 — Bootstrap the trust root](03-bootstrap-trust-root.md) · [Next: 05 — Infrastructure and DevSecOps](05-infrastructure-and-devsecops.md)
