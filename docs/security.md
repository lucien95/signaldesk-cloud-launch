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
| Public database login | No authorized networks; access through Cloud SQL integration |
| Secret committed to Git | Secret Manager and secret scanning in CI |
| Malicious container dependency | Pinned base family, dependency scan, image scan |
| Sensitive data in logs | Structured allow-list fields; no request body logging |
| Uncontrolled public API | Explicit unauthenticated IAM binding and documented boundary |
| Destructive infrastructure change | Reviewed Terraform plan and protected apply environment |

## Known first-release gaps

- The public API has no customer authentication or rate limiting.
- Terraform state contains sensitive resource metadata and must have tightly
  restricted bucket IAM and versioning.
- A database password is used for the first build; IAM database authentication
  is the preferred hardening exercise.
- WAF, managed TLS, and a custom domain require the load-balancer extension.
