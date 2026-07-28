# Portfolio case study

## Project title

**SignalDesk Cloud Launch: keyless, policy-gated delivery on Google Cloud**

## Verified implementation status

The trust bootstrap was applied on 2026-07-26. Its saved plan contained 29
additions with no changes or deletions, the custom OPA gate returned no denials,
and the exact binary plan applied successfully. State was migrated from the
temporary local backend to a private, versioned GCS backend.

The development platform and application were deployed and verified on
2026-07-27. GitHub Actions built and scanned one image, generated a CycloneDX
SBOM, authenticated to GCP with OIDC, pushed the image, resolved its SHA-256
digest, deployed a zero-traffic candidate, tested database-backed readiness,
promoted the verified revision, and tested the public service. A synthetic
booking was then created, retrieved, and updated through the live API, and its
request ID was correlated in Cloud Logging.

A subsequent Terraform 1.15.8 run reported **No changes**. OPA passed the real
plan, the apply job verified the saved plan checksum, and Terraform completed
with zero additions, changes, or deletions. Both CI service accounts have zero
user-managed keys. See the sanitized
[bootstrap verification record](evidence/bootstrap-verification.md) and
[deployment verification record](evidence/deployment-verification.md).

Rollback, failure-injection alerting, backup restoration, load measurement,
and final teardown remain explicit follow-up drills; this case study does not
claim those tests are complete.

## Business problem and target client

A small service business needs a booking API but has no platform team. Manual
console changes, permanent CI keys, unbounded serverless scaling, and an
internet-addressable database would create avoidable security, reliability, and
cost risks. The target client is a startup or small engineering team that needs
a credible GCP foundation and safe delivery path without adopting Kubernetes.

## Architecture and GCP services

- Cloud Run for the FastAPI service and revision traffic management.
- Artifact Registry for immutable container images and cleanup policies.
- Cloud SQL for PostgreSQL 18 with private IP, backups, PITR, audit flags, and
  encrypted client-certificate connections.
- Custom VPC, subnet flow logs, Direct VPC egress, and Private Service Access.
- Secret Manager for the generated database password.
- Cloud Logging, Monitoring uptime checks, and a Cloud Billing budget.
- GCS for versioned Terraform state and short-lived reviewed plans.
- IAM, Security Token Service, and Workload Identity Federation for keyless CI.
- GitHub Actions for PR validation, protected infrastructure delivery, and
  no-traffic application promotion.

## Implementation phases

1. Build and test the booking API locally.
2. Create the Terraform trust bootstrap and remote-state design.
3. Build development infrastructure and private application networking.
4. Add Checkov, custom OPA policies/tests, Trivy, dependency auditing, and SBOMs.
5. Add keyless plan-review-apply and candidate revision promotion workflows.
6. Deploy, exercise rollback and restore runbooks, measure, and publish
   sanitized evidence.

## Terraform and IaC plan

The repository has two Terraform roots. `bootstrap` is the manually operated
trust root; `environments/dev` is the repeatable delivery target. Both use
locked providers. State is versioned and private in GCS. The delivery pipeline
converts a saved plan to JSON for OPA, stores the hashed binary plan, and applies
only that approved artifact. Terraform owns platform configuration while the
application workflow owns the image, generated revision, and release-client
metadata.

## Security and DevSecOps

There are no service-account JSON keys. Separate WIF pools and service accounts
isolate infrastructure administration from application deployment. OIDC trust
uses immutable GitHub IDs, `main`, exact workflow files, and exact environment
claims. Checkov provides broad static IaC checks; OPA enforces SignalOps rules
on real plans; Trivy scans the repository and image; pip-audit checks Python
advisories; actions and tool downloads are immutable and verified. Images are
deployed by digest after a zero-traffic smoke test.

## Monitoring, logging, and reliability

The application emits structured JSON logs and request IDs. Cloud Run has
startup and liveness probes; Monitoring checks readiness. VPC flow logs,
Storage Data Access audit logs, Cloud SQL connection/audit flags, automated
backups, and PITR provide operating evidence. A rollback runbook returns traffic
to a known-good Cloud Run revision, while acceptance criteria require a timed
restore drill rather than an untested backup claim.

## Cost controls

Cloud Run scales to zero and is capped at three instances. Cloud SQL uses a
small zonal tier, storage autoscaling has a ceiling, Direct VPC egress avoids
connector instances, Artifact Registry removes old untagged images, pipeline
artifacts expire, and a USD 10 budget alerts at 50%, 90%, and 100%. The case
study explicitly states that a budget is not a hard cap.

## Deliverables and proof assets

- Architecture and trust-flow diagrams.
- Deployable Terraform and policy unit tests.
- GitHub Actions runs showing every security and deployment gate.
- Sanitized Terraform plan/apply and zero-key identity evidence.
- CycloneDX SBOM, clean image scan, and immutable deployed digest.
- Cloud Run candidate/promotion and live API acceptance evidence.
- Uptime, request-log correlation, and budget evidence.
- Cost assumptions, limitations, and teardown record.

Timed rollback, alert notification, database restore, load test, and teardown
records are still pending and are not represented as completed deliverables.

## Portfolio angle

Lead with the scanner-driven architecture improvement: Trivy blocked the first
public-IP Cloud SQL design, so the final build adopted Private Service Access
and Direct VPC egress. Then show how custom OPA rules capture business policies
that generic tools cannot know, such as the three-instance cost ceiling and the
rule that only the development service may be public. This demonstrates
engineering judgment, not merely tool installation.

The implementation story is equally valuable: real delivery surfaced a Cloud
SQL edition/tier mismatch, a Cloud Run probe incompatibility, normalized
resource names in Terraform plans, a nested `gcloud` formatting trap, and a
shared-ownership drift boundary between Terraform and application deployment.
Each issue was diagnosed from evidence, fixed in a focused pull request, gated,
and re-verified in the live environment.

## SignalOps service mapping

The primary service is **Cloud Foundation Launch**: project identity, remote
state, network, managed runtime, database, secrets, observability, budgets, and
operational runbooks. The keyless pipeline and policy gates are a **Secure
Delivery / DevSecOps Accelerator** add-on. The budget, scaling, and cleanup
controls support a **Cloud Cost Guardrails** engagement, while probes, uptime
checks, rollback, and recovery evidence support a **Reliability Baseline**.
