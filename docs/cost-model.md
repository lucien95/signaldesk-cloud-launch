# Cost controls and modeling

Do not publish a fixed monthly price without recording the calculator date,
region, request volume, database uptime, log volume, and network egress
assumptions. Cloud pricing changes and a precise-looking estimate without those
assumptions is misleading.

## Recurring cost drivers

- Cloud SQL compute, storage, backups, and network traffic.
- Cloud Run CPU, memory, requests, minimum instances, and egress.
- Artifact Registry storage.
- Cloud Logging ingestion and retention.
- Secret Manager access and stored versions.

## Guardrails in this project

- Cloud Run minimum instances default to zero.
- Cloud Run maximum instances default to three to protect both SQL and spend.
- Development Cloud SQL uses a small shared-core tier and zonal availability.
- Database disk autoscaling has an explicit upper limit.
- Artifact Registry removes old untagged images.
- Direct VPC egress avoids always-on connector instances.
- Temporary Terraform plans are removed after apply and expire after one day.
- Security evidence has short GitHub artifact retention periods.
- A billing budget is derived from the project's billing account; an explicit
  `billing_account_id` can override it when required.
- The default development budget alert is USD 10 per month.
- Development resources have a documented destroy path.

The USD 10 budget is an alert, not a spending cap. Cloud SQL compute continues
to run until the instance is stopped or destroyed. Database audit settings and
VPC flow logs improve evidence but can increase logging cost, so log volume is
part of the seven-day review.

## Cost review worksheet

Record the following before deployment and after a seven-day observation window:

| Input | Planned | Observed |
|---|---:|---:|
| Requests per month | | |
| Average request duration | | |
| Cloud Run instance hours | | |
| Database storage | | |
| Backup storage | | |
| Log ingestion | | |
| Internet egress | | |
| Total monthly run rate | | |
