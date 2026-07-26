# Bootstrap verification record

Verified on 2026-07-26 against the dedicated SignalDesk lab project. This
record intentionally omits the GCP project number, billing account identifier,
raw state, and credential material.

## Scope

The manually operated Terraform trust root creates only the prerequisites for
normal GitHub delivery:

- four required Google Cloud APIs;
- a private, versioned GCS state bucket with public-access prevention;
- separate application and infrastructure deployment service accounts;
- separate Workload Identity pools and GitHub OIDC providers;
- workflow-, branch-, repository-, owner-, and environment-bound trust rules;
- service-account impersonation, platform roles, state access, and budget
  management access;
- Cloud Storage data-access audit logging.

Cloud Run, Cloud SQL, Artifact Registry, networking, secrets, monitoring, and
the application are deliberately outside this bootstrap and were not claimed
as deployed by this verification.

## Evidence summary

| Check | Sanitized result |
|---|---|
| Operator identity | Expected project owner and project selected |
| Terraform CLI | Version aligned with the GitHub Actions workflow |
| Configuration | Formatting and validation passed |
| Saved plan | 29 additions, 0 changes, 0 deletions |
| SignalOps OPA gate | Empty denial set; policy gate passed |
| Apply | 29 resources added, 0 changed, 0 destroyed |
| State migration | Local bootstrap state copied to the protected GCS backend |
| Remote inventory | All 29 Terraform addresses readable from remote state |
| Remote object | Default workspace state present under `signaldesk/bootstrap` |
| Drift check | Post-migration plan returned exit code 0 and `No changes` |
| Local-state cleanup | Obsolete root-level local state copies removed after verification |
| Long-lived CI keys | Zero created or stored in GitHub |

## Control interpretation

The saved plan was converted to JSON and evaluated before apply. Applying the
binary plan ensured that the reviewed proposal was the executed proposal. A
second plan after migration reconciled configuration, remote state, and live
GCP resources and found no difference.

GitHub can authenticate only through short-lived OIDC exchange. Admission is
restricted to the immutable repository and owner IDs, the `main` branch, exact
workflow paths, and exact GitHub environment names. Separate identities keep a
routine application release from inheriting infrastructure administration.

## Remaining proof

The next evidence milestone is the first protected `main` delivery: successful
pull-request gates, policy-checked development plan, approved exact-plan apply,
container scan and SBOM, zero-traffic candidate deployment, readiness test, and
traffic promotion. Rollback, alerting, backup restoration, and cost observation
remain explicit follow-up drills rather than unverified claims.
