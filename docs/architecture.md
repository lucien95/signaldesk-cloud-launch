# Architecture decisions

## Why Cloud Run

The target client needs a managed container runtime, not a Kubernetes platform.
Cloud Run keeps the application portable while removing cluster and node
operations. Scaling is bounded to protect the database and the budget.

## Why Cloud SQL

Bookings are transactional and benefit from relational constraints and familiar
PostgreSQL tooling. A managed database provides automated backups and a clear
recovery path. The development environment is zonal; high availability is an
explicit production upgrade based on the client's recovery requirements.

## Infrastructure and application ownership

Terraform owns APIs, IAM, Artifact Registry, Cloud SQL, Secret Manager, Cloud
Run configuration, monitoring, and budgets. The deployment workflow owns the
Cloud Run container image and revision promotion. Terraform ignores image drift
to prevent the two delivery paths from fighting each other.

## Deliberate first-release constraints

- One GCP region.
- Cloud Run URL instead of a custom domain and global load balancer.
- Public Cloud SQL address used only through the Cloud Run Cloud SQL connector;
  no authorized public client networks.
- Zonal development database.
- Password authentication with the password held in Secret Manager.

These constraints keep the lab affordable and buildable. The production design
review must consider private IP, IAM database authentication, HA, PITR, custom
domain, Cloud Armor, and a tested regional recovery strategy.
