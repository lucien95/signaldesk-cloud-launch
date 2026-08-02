# LinkedIn launch post

I just deployed SignalDesk Cloud Launch—a production-style GCP booking platform
built to answer a practical question:

How do you give a small business online booking without creating a fragile,
manual, or unnecessarily complex cloud platform?

The application is a real end-to-end build:

- Next.js customer and operations interface
- FastAPI backend
- private Cloud SQL for PostgreSQL
- Cloud Run with scale-to-zero and a maximum of three instances
- Secret Manager database-password injection
- Terraform-managed networking, IAM, monitoring, and budget controls
- keyless GitHub Actions authentication through Workload Identity Federation
- Checkov, custom OPA policies, Trivy, dependency audits, and CycloneDX SBOMs
- zero-traffic candidate deployment before Cloud Run promotion
- structured request IDs correlated from the browser into Cloud Logging

One of the most useful lessons was identity separation:

GitHub’s deployment identity is not the Cloud Run runtime identity, and the
Cloud Run service account is not the PostgreSQL user. Each layer has a distinct
authentication and authorization job.

I also documented the problems that improved the design: a scanner-driven move
away from public database networking, Cloud SQL tier compatibility, Cloud Run
probe constraints, Terraform/OPA plan normalization, candidate lookup failure,
and shared ownership between Terraform and application deployment.

This is a synthetic-data reference implementation, not a client case study. I
have clearly documented the remaining production work, including staff RBAC,
rate limiting, edge protection, and completed restore/load/alert drills.

Project page: [PORTFOLIO_URL]

GitHub: https://github.com/lucien95/signaldesk-cloud-launch

Live demonstration: https://signaldesk-dev-s2wvuscfya-ue.a.run.app

#GoogleCloud #Terraform #DevOps #PlatformEngineering #CloudRun #GitHubActions #DevSecOps #SRE #CloudSecurity

## Suggested first comment

The delivery evidence includes:

- six green pull-request jobs;
- separate application and infrastructure OIDC pools;
- a hashed, policy-checked Terraform plan applied as the exact approved binary;
- a scanned image deployed by immutable digest;
- candidate smoke tests before 100% traffic promotion;
- a customer-visible request ID found in the matching structured Cloud Run log.

Technical walkthrough: [MEDIUM_OR_SUBSTACK_URL]

