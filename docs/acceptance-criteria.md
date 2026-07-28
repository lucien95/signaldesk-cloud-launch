# Acceptance criteria and evidence plan

The project is not complete until each claim can be supported by repeatable
evidence. Store sanitized screenshots, command output, and measurements in a
private evidence folder before selecting material for public use.

The first sanitized proof asset is the
[bootstrap verification record](evidence/bootstrap-verification.md). It proves
the trust root and remote-state milestone. The
[deployment verification record](evidence/deployment-verification.md) proves
the runtime, delivery, database, observability, identity, cost, and final
zero-drift milestones. Operational drills that remain incomplete are marked
honestly below.

| Capability | Acceptance test | Status | Evidence |
|---|---|---|---|
| Application | Create, retrieve, and update a booking | Verified | Synthetic live API test and deployment record |
| Infrastructure | Reconcile dev from Terraform | Verified | No-change plan, OPA pass, checksum verification, and no-op apply |
| Keyless CI/CD | GitHub deploys without a service-account JSON key | Verified | OIDC workflow and zero user-managed keys on both CI identities |
| Policy as code | A deliberately insecure plan fails before apply | Verified | Ten OPA unit tests and real-plan policy gate |
| IaC security | Checkov reports no unexplained failures | Verified | 514 passed, zero failed, three documented skips |
| Supply chain | Image is scanned and identified by digest | Verified | Trivy gates, CycloneDX SBOM artifact, and deployed SHA-256 digest |
| Release safety | Verify a zero-traffic candidate before promotion | Verified | Candidate smoke test and post-promotion public check |
| Failure safety | Reject a bad candidate without moving traffic | Pending drill | Failed-candidate traffic evidence |
| Rollback | Restore the previous revision within 10 minutes | Pending drill | Timed rollback record |
| Availability | Liveness and readiness failures are distinguishable | Verified | Public health tests and database-backed readiness |
| Observability | One request can be followed by request ID | Verified | Correlated HTTP 201 structured log on the serving revision |
| Alerting | A controlled 5xx event reaches the configured channel | Pending drill | Alert incident screenshot |
| Recovery | Restore a backup to a new database instance | Pending drill | Restore log and validation query |
| Security | Public exposure and IAM are documented and reviewed | Verified | Security model, private database path, and dedicated identities |
| Cost | Budget exists and all recurring resources are itemized | Verified | USD 10 budget thresholds and cost model |
| Teardown | Dev resources can be destroyed without orphaned resources | Pending final teardown | Destroy output and inventory check |

## Portfolio measurements

Capture at minimum:

- infrastructure provisioning time;
- application deployment time;
- rollback time;
- backup restoration time;
- p95 API latency under the documented test load;
- steady-state development cost estimate;
- number of long-lived cloud credentials required, with a target of zero.
