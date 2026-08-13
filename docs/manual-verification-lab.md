# SignalDesk manual verification lab

This lab turns the deployed project into repeatable hands-on experience. Do not
just read the commands. Run one checkpoint at a time, explain the result in your
own words, and save only sanitized evidence.

## Rules before you begin

- Run from the repository root.
- Stop immediately if the active account or project is wrong.
- Use only synthetic `example.com` customer data.
- Never print a secret payload, access token, Terraform state, billing-account
  identifier, private IP address, or raw credential file into public evidence.
- The commands in checkpoints 0–11 are inspection or controlled API test
  commands. Do not run `terraform apply`, `terraform destroy`, traffic changes,
  a database restore, or IAM mutations during this review.
- A passing command is not the learning objective. Be able to explain what
  boundary it verifies and what risk that boundary reduces.

## Learning map

Open both diagrams before starting:

- [Runtime architecture](diagrams/signaldesk-runtime-architecture.svg)
- [CI/CD and trust architecture](diagrams/signaldesk-delivery-architecture.svg)
- [Editable two-page diagram](diagrams/signaldesk-architecture.drawio)

The numbered connections in the diagrams match the concepts you will verify:

1. public request or pull-request entry point;
2. secret or infrastructure OIDC boundary;
3. Direct VPC egress or application delivery branch;
4. private-service or approved-plan integrity step;
5. private database or immutable artifact step;
6. logs and metrics;
7. database-backed readiness.

## Checkpoint 0 — prove your local context

### Concept

The Google Cloud CLI account is the human identity. The configured project is
the default resource scope. The ADC quota project attributes client-library
quota and some API usage to this project; it is not a separate project and does
not move resources.

### Run

```bash
export PROJECT_ID="kloudwithlucien-503200"
export REGION="us-east1"
export SERVICE="signaldesk-dev"
export REPOSITORY="lucien95/signaldesk-cloud-launch"
export STATE_BUCKET="${PROJECT_ID}-signaldesk-tfstate"
export INFRA_SA="signaldesk-terraform-deploy@${PROJECT_ID}.iam.gserviceaccount.com"
export APP_SA="signaldesk-github-deploy@${PROJECT_ID}.iam.gserviceaccount.com"
export RUNTIME_SA="signaldesk-dev-runtime@${PROJECT_ID}.iam.gserviceaccount.com"

pwd
git status -sb
gcloud auth list --filter=status:ACTIVE --format='value(account)'
gcloud config get-value project
jq -r '.quota_project_id' ~/.config/gcloud/application_default_credentials.json
gcloud billing projects describe "${PROJECT_ID}" --format='value(billingEnabled)'
```

### Expect

- account: the intended project-owning Google account;
- project and ADC quota project: `kloudwithlucien-503200`;
- billing enabled: `True`;
- repository branch and worktree state are understood before any change.

### Interview explanation

> I separated human administration from automated delivery. My local ADC uses
> the project as its quota project, while GitHub uses short-lived federated
> identities. The quota project is accounting context, not an isolated workload
> project.

## Checkpoint 1 — inspect the one-time trust bootstrap

### Concept

Bootstrap solves the chicken-and-egg problem: Terraform state cannot be stored
in a bucket until a bucket exists. A reviewed local apply creates the protected
state bucket, two Workload Identity Federation providers, and two deployer
service accounts. State is then migrated from local storage into GCS.

### Run

```bash
terraform -chdir=terraform/bootstrap init \
  -input=false \
  -lockfile=readonly \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="prefix=signaldesk/bootstrap"
terraform -chdir=terraform/bootstrap output

gcloud storage buckets describe "gs://${STATE_BUCKET}" \
  --format='yaml(name,location,iamConfiguration.uniformBucketLevelAccess.enabled,iamConfiguration.publicAccessPrevention,versioning.enabled)'

for pool in signaldesk-infra signaldesk-app; do
  gcloud iam workload-identity-pools describe "${pool}" \
    --project="${PROJECT_ID}" \
    --location=global \
    --format='table(name.basename(),state,displayName)'
done

gcloud iam workload-identity-pools providers describe github \
  --project="${PROJECT_ID}" \
  --location=global \
  --workload-identity-pool=signaldesk-infra \
  --format='yaml(attributeMapping,attributeCondition,oidc.issuerUri)'

gcloud iam workload-identity-pools providers describe github \
  --project="${PROJECT_ID}" \
  --location=global \
  --workload-identity-pool=signaldesk-app \
  --format='yaml(attributeMapping,attributeCondition,oidc.issuerUri)'
```

### Expect

- the bucket is versioned, uses uniform access, and enforces public-access
  prevention;
- two active pools exist: one for infrastructure and one for the application;
- conditions bind immutable repository and owner IDs, `main`, expected workflow
  paths, and exact GitHub environment names;
- infrastructure accepts only `infrastructure-plan` and
  `infrastructure-development`; application accepts only `development`.

### What this proves

Possessing any GitHub OIDC token is not enough. GCP verifies the issuer and the
mapped claims before a repository job can impersonate a service account.

## Checkpoint 2 — prove there are no long-lived CI keys

### Run

```bash
for service_account in "${INFRA_SA}" "${APP_SA}"; do
  echo "User-managed keys for ${service_account}:"
  gcloud iam service-accounts keys list \
    --iam-account="${service_account}" \
    --managed-by=user \
    --format='table(name.basename(),validAfterTime,validBeforeTime)'
done
```

### Expect

Both lists contain zero rows. Google-managed keys are normal; the security claim
is specifically zero downloadable user-managed keys.

### Interview explanation

> GitHub requests a signed OIDC token for one job. GCP validates immutable
> repository, branch, workflow, and environment claims, then grants a
> short-lived service-account credential. There is no JSON key to leak, rotate,
> or copy between repositories.

## Checkpoint 3 — verify remote state, drift, and the real-plan policy gate

### Concept

Terraform state records resource identity and dependencies. The GCS backend
provides a shared, versioned source of truth and state locking. OPA evaluates
the actual Terraform plan JSON, not only the source files.

### Run

```bash
test -f terraform/environments/dev/terraform.tfvars

terraform -chdir=terraform/environments/dev init \
  -input=false \
  -lockfile=readonly \
  -backend-config="bucket=${STATE_BUCKET}" \
  -backend-config="prefix=signaldesk/dev"

terraform -chdir=terraform/environments/dev state list | sort

terraform -chdir=terraform/environments/dev plan \
  -lock-timeout=5m \
  -out=/tmp/signaldesk-manual.tfplan

terraform -chdir=terraform/environments/dev show -json \
  /tmp/signaldesk-manual.tfplan > /tmp/signaldesk-manual-plan.json

make opa-eval PLAN_JSON=/tmp/signaldesk-manual-plan.json
shasum -a 256 /tmp/signaldesk-manual.tfplan
```

### Expect

- the state list includes VPC, Cloud SQL, Secret Manager, Cloud Run, monitoring,
  IAM, Artifact Registry, and budget resources;
- Terraform reports `No changes`;
- OPA reports that the policy gate passed;
- the binary plan has a SHA-256 digest.

Remove only the temporary verification artifacts afterward:

```bash
rm /tmp/signaldesk-manual.tfplan /tmp/signaldesk-manual-plan.json
```

### What this proves

The deployed platform matches the declared configuration. In CI, the plan job
stores the binary plan and checksum, and the protected apply job verifies and
applies that exact artifact. A fresh unreviewed re-plan is not substituted after
approval.

## Checkpoint 4 — compare the three IAM blast radii

### Run

```bash
for service_account in "${INFRA_SA}" "${APP_SA}" "${RUNTIME_SA}"; do
  echo "Roles for ${service_account}:"
  gcloud projects get-iam-policy "${PROJECT_ID}" \
    --flatten='bindings[].members' \
    --filter="bindings.members:serviceAccount:${service_account}" \
    --format='table(bindings.role)'
done
```

Also inspect service-account-level `actAs` and federation bindings:

```bash
gcloud iam service-accounts get-iam-policy "${RUNTIME_SA}" \
  --format='table(bindings.role,bindings.members)'

gcloud iam service-accounts get-iam-policy "${APP_SA}" \
  --format='table(bindings.role,bindings.members)'

gcloud iam service-accounts get-iam-policy "${INFRA_SA}" \
  --format='table(bindings.role,bindings.members)'
```

### Expect

- application deployer: Artifact Registry writer and Cloud Run developer;
- runtime identity: Cloud SQL client, log writer, metric writer, and secret
  accessor;
- infrastructure deployer: broader platform-management roles plus protected
  state access;
- WIF principals can impersonate only their matching deployer identity;
- deployment identities may act as the runtime identity, but the application
  process does not inherit infrastructure-admin permissions.

### Business reason

A compromised release job should not be able to rewrite federation, networking,
Terraform state, or the database platform. A compromised application container
should not receive deployment or project-administration permissions.

## Checkpoint 5 — inspect the immutable Cloud Run release

### Run

```bash
export SERVICE_URL="$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='value(status.url)')"

export REVISION="$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='value(status.latestReadyRevisionName)')"

printf 'Service URL: %s\nRevision: %s\n' "${SERVICE_URL}" "${REVISION}"

gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='yaml(status.traffic,spec.template.spec.serviceAccountName,spec.template.spec.containers)'

gcloud run revisions describe "${REVISION}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='value(spec.containers[0].image)'

gcloud run services get-iam-policy "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='table(bindings.role,bindings.members)'
```

### Expect

- 100% traffic targets the serving revision;
- the image uses an immutable `@sha256:...` digest;
- the service uses the dedicated runtime service account;
- scaling and resource settings match 0–3 instances, 1 vCPU, and 512 MiB;
- `allUsers` has only `roles/run.invoker`, which is the deliberate public-demo
  exposure.

### Interview explanation

> The pipeline builds once, scans that image, pushes it, resolves its registry
> digest, and deploys the digest with zero traffic. Readiness is tested on the
> candidate URL before the exact revision receives 100% traffic.

## Checkpoint 6 — trace the private database network path

### Run

```bash
gcloud compute networks describe signaldesk-dev \
  --project="${PROJECT_ID}" \
  --format='yaml(name,autoCreateSubnetworks,routingConfig.routingMode)'

gcloud compute networks subnets describe signaldesk-dev \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='yaml(name,ipCidrRange,privateIpGoogleAccess,logConfig)'

gcloud compute networks peerings list \
  --project="${PROJECT_ID}" \
  --network=signaldesk-dev \
  --format='table(name,state,stateDetails,peerNetwork)'

gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --format='yaml(spec.template.metadata.annotations)'

gcloud sql instances describe signaldesk-dev \
  --project="${PROJECT_ID}" \
  --format='yaml(state,region,databaseVersion,settings.tier,settings.availabilityType,settings.ipConfiguration,settings.backupConfiguration,settings.insightsConfig,ipAddresses)'
```

### Expect

- custom-mode VPC with regional routing;
- subnet `10.10.0.0/24`, private Google access, and flow logs;
- active Service Networking peering;
- Cloud Run Direct VPC egress configured for private ranges;
- Cloud SQL is `RUNNABLE`, zonal PostgreSQL 18, and has a private address only;
- public IPv4 is disabled, backups and PITR are enabled, and SSL requires a
  trusted client certificate.

### Important architecture nuance

Cloud Run is a managed serverless service; it is not a VM inside the subnet.
Direct VPC egress attaches its outbound private-range traffic to the subnet.
Cloud SQL is also managed; Private Service Access connects the VPC to the
service producer network where the private database address lives.

## Checkpoint 7 — verify secret wiring without revealing the secret

### Run

```bash
gcloud secrets describe signaldesk-dev-database-password \
  --project="${PROJECT_ID}" \
  --format='yaml(name,replication,labels,createTime)'

gcloud secrets versions list signaldesk-dev-database-password \
  --project="${PROJECT_ID}" \
  --format='table(name,state,createTime)'

gcloud secrets get-iam-policy signaldesk-dev-database-password \
  --project="${PROJECT_ID}" \
  --format='table(bindings.role,bindings.members)'
```

### Expect

- an enabled version exists;
- the runtime identity is allowed to access the secret;
- the value itself never appears.

Do **not** run `gcloud secrets versions access` for this verification. The goal
is to prove secure wiring, not expose the credential.

## Checkpoint 8 — execute one end-to-end database transaction

### Concept

`/health/live` proves that the process responds. `/health/ready` executes
`SELECT 1`, proving database connectivity. Creating, retrieving, and updating a
booking verifies validation, secret injection, the Cloud SQL connector, Direct
VPC egress, PostgreSQL persistence, and response serialization.

### Run

```bash
curl --fail --silent --show-error "${SERVICE_URL}/health/live" | jq .
curl --fail --silent --show-error "${SERVICE_URL}/health/ready" | jq .

export REQUEST_ID="manual-verification-$(date -u +%Y%m%dT%H%M%SZ)"

export BOOKING_JSON="$(curl --fail --silent --show-error \
  -X POST "${SERVICE_URL}/api/v1/bookings" \
  -H 'content-type: application/json' \
  -H "x-request-id: ${REQUEST_ID}" \
  -d '{
    "customer_name": "SignalOps Verification",
    "customer_email": "signaldesk-verification@example.com",
    "service": "Cloud architecture review",
    "scheduled_at": "2026-12-15T15:00:00Z"
  }')"

echo "${BOOKING_JSON}" | jq .
export BOOKING_ID="$(echo "${BOOKING_JSON}" | jq -r '.id')"

curl --fail --silent --show-error \
  "${SERVICE_URL}/api/v1/bookings/${BOOKING_ID}" | jq .

curl --fail --silent --show-error \
  -X PATCH "${SERVICE_URL}/api/v1/bookings/${BOOKING_ID}/status" \
  -H 'content-type: application/json' \
  -d '{"status":"completed"}' | jq .
```

### Expect

- liveness returns `ok`;
- readiness returns `ready`;
- create returns HTTP 201 and a UUID;
- the same record is retrieved from PostgreSQL;
- status changes from `confirmed` to `completed`.

The demonstration API intentionally has no delete endpoint. Keep the data
synthetic and identify it clearly as verification data.

## Checkpoint 9 — correlate the transaction in Cloud Logging

### Run

```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE} AND jsonPayload.request_id=\"${REQUEST_ID}\"" \
  --project="${PROJECT_ID}" \
  --freshness=30m \
  --limit=10 \
  --format='table(timestamp,resource.labels.revision_name,jsonPayload.method,jsonPayload.path,jsonPayload.status,jsonPayload.duration_ms,jsonPayload.message)'

gcloud monitoring uptime list-configs \
  --project="${PROJECT_ID}" \
  --format='table(displayName,period,timeout,httpCheck.path,httpCheck.useSsl)'
```

### Expect

- the POST log has your request ID, HTTP method, path, status 201, duration, and
  serving revision;
- an uptime check calls `/health/ready` every 60 seconds over HTTPS.

### Honest limitation

An uptime check collects health results, but this Terraform currently does not
create an alert policy and notification channel for that check. A controlled
5xx notification drill is still pending. Do not describe uptime checking as
completed paging or incident response.

## Checkpoint 10 — audit the delivery evidence in GitHub

### Run

```bash
gh run view 30317964082 \
  --repo="${REPOSITORY}" \
  --json status,conclusion,headSha,url,jobs \
  --jq '{status,conclusion,headSha,url,jobs:[.jobs[]|{name,conclusion}]}'

gh run view 30318924512 \
  --repo="${REPOSITORY}" \
  --json status,conclusion,headSha,url,jobs \
  --jq '{status,conclusion,headSha,url,jobs:[.jobs[]|{name,conclusion}]}'

gh variable list --repo="${REPOSITORY}"
gh secret list --repo="${REPOSITORY}"

gh api "repos/${REPOSITORY}/actions/runs/30317964082/artifacts" \
  --jq '.artifacts[] | {name,expired,expires_at}'
```

### Expect

- application, Terraform, and DevSecOps gates passed;
- infrastructure plan, approval/apply, image release, candidate test, and
  promotion are visible as separate jobs;
- repository configuration contains identifiers, not a GCP JSON key;
- the release produced a CycloneDX SBOM artifact, subject to its retention
  window;
- the final reconciliation run reports no drift and applies zero changes.

### File-to-pipeline trace

| File | Responsibility |
|---|---|
| `.github/workflows/ci.yml` | Python quality and dependency audit |
| `.github/workflows/terraform.yml` | Terraform formatting and validation |
| `.github/workflows/security.yml` | Checkov, OPA tests, Trivy, actionlint, SBOM |
| `.github/workflows/delivery.yml` | Trusted-main orchestration and exact-plan apply |
| `.github/workflows/deploy.yml` | Build, scan, push, candidate test, promotion |
| `terraform/bootstrap/` | Trust root, state bucket, WIF, deploy identities |
| `terraform/environments/dev/` | Runtime platform, network, data, monitoring, cost |
| `policy/terraform/` | SignalOps-specific plan rules and policy tests |

## Checkpoint 11 — verify cost and recovery controls

### Run

```bash
export BILLING_ACCOUNT="$(gcloud billing projects describe "${PROJECT_ID}" \
  --format='value(billingAccountName.basename())')"

gcloud billing budgets list \
  --billing-account="${BILLING_ACCOUNT}" \
  --filter='displayName="SignalDesk dev monthly budget"' \
  --format='table(displayName,amount.specifiedAmount.currencyCode,amount.specifiedAmount.units,thresholdRules.thresholdPercent)'

gcloud artifacts repositories describe signaldesk \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --format='yaml(format,cleanupPolicies)'

gcloud sql backups list \
  --project="${PROJECT_ID}" \
  --instance=signaldesk-dev \
  --limit=10 \
  --format='table(id,status,startTime,endTime,type)'

gcloud run revisions list \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --service="${SERVICE}" \
  --format='table(metadata.name,status.conditions[0].status,metadata.creationTimestamp)'
```

### Expect

- $10 budget with 50%, 90%, and 100% thresholds;
- Cloud Run min zero and max three, checked in checkpoint 5;
- small zonal Cloud SQL tier with disk growth capped at 25 GB, checked in
  checkpoint 6;
- Artifact Registry deletes untagged images older than seven days;
- successful backups exist and prior Cloud Run revisions are available.

A budget sends notifications; it is **not** a hard spending cap. A listed backup
does not prove restoration. A prior revision does not prove the team can roll
back inside the target time.

## Checkpoint 12 — identify what is proven and what remains a drill

Verified now:

- keyless CI authentication;
- separated infrastructure, application, and runtime identities;
- policy-gated exact Terraform plans;
- immutable image deployment and candidate promotion;
- private Cloud SQL connectivity;
- secret injection without repository credentials;
- database-backed readiness and structured request correlation;
- cost alerts and bounded scaling.

Still to execute deliberately:

- reject a known-bad candidate while proving traffic stays on the prior revision;
- perform and time a Cloud Run rollback;
- create an alert policy and verify a controlled 5xx notification;
- restore a backup into a separate Cloud SQL instance and validate data;
- run a documented load test and record p95 latency;
- perform final teardown and orphan-resource inventory.

These are not documentation defects to hide. They are the next reliability
iteration and strong interview discussion points about evidence versus claims.

## Mastery review

Do not mark the lab complete until you can answer these without reading:

1. Why must bootstrap run locally once?
2. Why are the application and infrastructure WIF pools separate?
3. Which OIDC claims prevent another repository or workflow from deploying?
4. Why store and hash a binary Terraform plan?
5. What different questions do Checkov, OPA, and Trivy answer?
6. Why is Cloud Run not considered a VM inside the VPC subnet?
7. How does Cloud Run reach a Cloud SQL instance with no public IPv4 address?
8. What does `/health/live` prove that `/health/ready` does not, and vice versa?
9. Why does a zero-traffic candidate make deployment failure safer?
10. Why is a $10 budget not a $10 spending cap?
11. Which production upgrades depend on client RTO, RPO, threat model, and
    budget?
12. Which six operational claims are still pending real drills?

When you can answer all twelve and reproduce the evidence, you can explain this
project as an engineer rather than as someone who followed a tutorial.
