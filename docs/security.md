# Security model

## Protected assets

- Customer names, email addresses, service selections, and booking times.
- Database credentials and backup data.
- Deployment identity and production configuration.
- Audit and application logs.

## Primary threats and controls

| Threat | Initial control |
|---|---|
| Stolen CI credential | GitHub OIDC and Workload Identity Federation; no JSON key |
| Excessive runtime access | Dedicated Cloud Run service account with narrow roles |
| Public database login | No public database IP; Direct VPC egress and trusted client certificates |
| Secret committed to Git | Secret Manager and secret scanning in CI |
| Malicious container dependency | Dependency audit, image scan, SBOM, and digest deployment |
| Sensitive data in logs | Structured allow-list fields; no request body logging |
| Uncontrolled public API | Explicit unauthenticated IAM binding and documented boundary |
| Destructive infrastructure change | OPA deletion rules, `prevent_destroy`, hashed plan, and protected apply environment |
| CI supply-chain substitution | GitHub Actions pinned to commit SHAs; OPA and Trivy downloads verified by SHA-256 |
| Repository rename or takeover | OIDC trust uses immutable GitHub repository and owner IDs |

## Scanner exceptions

Checkov exceptions are inline beside the affected resource rather than hidden
in a central skip list:

- the state bucket uses Cloud Audit Logs for data access instead of a second
  server-access-log bucket;
- the isolated development Artifact Registry uses Google-managed encryption;
- the infrastructure identity needs service-account administration to create a
  runtime identity and manage its narrow `actAs` bindings. Its separate WIF
  pool, exact workflow claims, and protected apply environment reduce that
  privilege's exposure.

## Known first-release gaps

- The public API has no customer authentication or rate limiting.
- Terraform state contains sensitive resource metadata and must have tightly
  restricted bucket IAM and versioning.
- A database password is used for the first build; IAM database authentication
  is the preferred hardening exercise.
- PostgreSQL audit flags are configured, but the `pgaudit` extension still
  needs a controlled database-migration step before claiming query audit is
  fully active.
- WAF, managed TLS, and a custom domain require the load-balancer extension.
