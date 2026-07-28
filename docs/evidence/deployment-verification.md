# Deployment verification record

Verified on 2026-07-27 in `us-east1`. GitHub timestamps in linked runs are UTC.
This record intentionally excludes billing-account identifiers, project
numbers, credentials, secret values, raw state, and non-synthetic user data.

## Outcome

SignalDesk is running as a public development demonstration at
<https://signaldesk-dev-s2wvuscfya-ue.a.run.app>. The service is backed by a
private Cloud SQL PostgreSQL database and was released by a keyless,
policy-gated GitHub Actions pipeline.

The successful application delivery is recorded in
[Main delivery run 30317964082](https://github.com/lucien95/signaldesk-cloud-launch/actions/runs/30317964082).
The final infrastructure reconciliation is recorded in
[Main delivery run 30318924512](https://github.com/lucien95/signaldesk-cloud-launch/actions/runs/30318924512).

## Release evidence

- Serving revision: `signaldesk-dev-00003-jut`.
- Production traffic: 100% to the serving revision.
- Deployed image digest:
  `sha256:e12fb1bbe172d1f8e6189882ab99860f86ab9faa17658db2efc7b2541ea04a97`.
- The image tag was the trusted `main` commit
  `8b2231ff02c989f5a56700fa1e31caa1e31acc9d`.
- The workflow built the release once, ran Trivy, generated a CycloneDX SBOM,
  pushed the scanned image, resolved the digest, and deployed by digest.
- The candidate revision received zero production traffic until
  `/health/ready` passed.
- Candidate promotion and the public post-promotion readiness test passed.

Pull request
[#19](https://github.com/lucien95/signaldesk-cloud-launch/pull/19)
corrected the nested Cloud Run candidate lookup that initially stopped the
pipeline before smoke testing. The pre-existing revision kept 100% traffic
during that failure, demonstrating the intended safety boundary.

## Runtime acceptance evidence

The public endpoints returned:

```text
/              -> {"service":"signaldesk-api","environment":"dev","docs":"/docs"}
/health/live   -> {"status":"ok"}
/health/ready  -> {"status":"ready"}
```

A synthetic booking using an `example.com` address was created with HTTP 201,
retrieved from PostgreSQL, and updated from `confirmed` to `completed`. The
create request used request ID `portfolio-acceptance-20260727`.

Cloud Logging correlated that request ID on the serving revision:

```text
message=request_completed method=POST path=/api/v1/bookings
status=201 duration_ms=115.46 revision=signaldesk-dev-00003-jut
```

This single test crosses the public Cloud Run endpoint, application validation,
Secret Manager configuration, Direct VPC egress, private Cloud SQL connection,
database transaction, response middleware, and structured logging path.

## Platform and security evidence

- Cloud Run uses a dedicated runtime service account, 1 vCPU, 512 MiB memory,
  minimum zero instances, and maximum three instances.
- Startup and HTTP liveness probes are configured; readiness checks execute a
  database query.
- Cloud Run uses Direct VPC egress for private ranges.
- Cloud SQL is `RUNNABLE`, PostgreSQL 18 Enterprise, `db-f1-micro`, private-IP
  only, with automated backups and point-in-time recovery enabled.
- The application and infrastructure GitHub service accounts each have zero
  user-managed keys.
- GitHub obtains short-lived credentials through separate workload identity
  pools and identities for application and infrastructure delivery.
- Checkov reported 514 passed checks, zero failures, and three documented
  skips. The custom OPA suite passed 10 of 10 tests.
- The release gates include Ruff, Bandit, pytest, pip-audit, actionlint,
  Checkov, OPA, Trivy filesystem/image scans, and SBOM generation.

## Cost evidence

- The monthly development budget is USD 10.
- Alert thresholds are 50%, 90%, and 100%.
- Cloud Run scales to zero and is capped at three instances.
- Cloud SQL uses a small zonal development tier.
- Direct VPC egress avoids an always-on Serverless VPC Access connector.
- Artifact Registry has an untagged-image cleanup policy.

A budget is an alerting control, not a hard spending cap.

## Terraform reconciliation evidence

Pull request
[#20](https://github.com/lucien95/signaldesk-cloud-launch/pull/20)
formalized shared ownership: Terraform owns the Cloud Run platform while the
release workflow owns its image, generated revision, and deployment-client
metadata. Provider quota requests are explicitly attributed to the managed
project.

The protected main workflow then produced this result with Terraform 1.15.8:

```text
No changes. Your infrastructure matches the configuration.
OPA policy gate passed
tfplan: OK
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

The plan and checksum were stored in the protected state bucket between jobs.
The apply job downloaded them, verified the checksum, applied only that binary
plan, and removed both short-lived plan artifacts after success.

## Evidence still required

The following are intentionally not claimed as complete:

- rejected bad-candidate drill;
- timed traffic rollback;
- controlled 5xx alert notification;
- backup restoration into a separate instance;
- documented load and p95 latency measurement;
- final Terraform teardown and orphan inventory.
