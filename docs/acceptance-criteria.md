# Acceptance criteria and evidence plan

The project is not complete until each claim can be supported by repeatable
evidence. Store sanitized screenshots, command output, and measurements in a
private evidence folder before selecting material for public use.

| Capability | Acceptance test | Evidence |
|---|---|---|
| Application | Create, retrieve, and update a booking | API test output and demo recording |
| Infrastructure | Recreate dev from Terraform | Successful plan/apply summary |
| Keyless CI/CD | GitHub deploys without a service-account JSON key | Workflow permissions and WIF audit log |
| Release safety | Deploy a bad revision without sending production traffic | Cloud Run revision and traffic screenshots |
| Rollback | Restore the previous revision within 10 minutes | Timed rollback drill |
| Availability | Liveness and readiness failures are distinguishable | Health endpoint tests and logs |
| Observability | One request can be followed by request ID | Correlated request and application logs |
| Alerting | A controlled 5xx event reaches the configured channel | Alert incident screenshot |
| Recovery | Restore a backup to a new database instance | Restore log and validation query |
| Security | Public exposure and IAM are documented and reviewed | Threat model and IAM matrix |
| Cost | Budget exists and all recurring resources are itemized | Budget screenshot and cost model |
| Teardown | Dev resources can be destroyed without orphaned resources | Destroy output and inventory check |

## Portfolio measurements

Capture at minimum:

- infrastructure provisioning time;
- application deployment time;
- rollback time;
- backup restoration time;
- p95 API latency under the documented test load;
- steady-state development cost estimate;
- number of long-lived cloud credentials required, with a target of zero.
