# 00 — Orient the project before building

## Outcome

You can explain the client problem, runtime path, delivery path, trust
boundaries, cost boundary, and deliberate development tradeoffs before opening
a cloud console.

## Business reason

A small service business needs a booking API, but it also needs evidence that
customer data is not sitting in a public database, releases are controlled,
costs are bounded, and an engineering team can operate the service. SignalDesk
turns those requirements into a compact platform that can be deployed and
demonstrated without pretending a development build has every enterprise
control.

This maps to the SignalOps **Cloud Launch**, **DevSecOps Delivery**,
**Reliability and Observability**, and **Cost Guardrails** services.

## Concepts

Open the two diagrams side by side:

- [Runtime architecture](../diagrams/signaldesk-runtime-architecture.svg)
- [CI/CD and trust architecture](../diagrams/signaldesk-delivery-architecture.svg)
- [Editable two-page source](../diagrams/signaldesk-architecture.drawio)

Trace the runtime request:

1. A client sends HTTPS traffic to the public Cloud Run service.
2. Cloud Run injects a database credential from Secret Manager into the
   dedicated runtime identity.
3. Private-range traffic leaves Cloud Run through Direct VPC egress.
4. Private Service Access connects the custom VPC to Google's managed service
   network.
5. Cloud SQL accepts the private database connection; it has no public IPv4
   address.
6. The application emits structured logs and platform metrics.
7. Monitoring calls the database-backed `/health/ready` endpoint.

Trace the delivery path:

1. Pull requests run tests and security checks without cloud write access.
2. A trusted `main` job requests a GitHub OIDC token.
3. GCP validates immutable repository, branch, workflow, and environment claims.
4. The infrastructure lane creates, policy-checks, hashes, stores, approves,
   and applies one exact Terraform plan.
5. The application lane builds once, scans the image, records an SBOM, pushes
   it, resolves its digest, and deploys a zero-traffic candidate.
6. The candidate reaches 100% traffic only after readiness succeeds.

## Before you run anything

- Read [Screenshot standards](screenshot-standards.md).
- Use synthetic data only.
- Treat the USD 10 budget as an alert, not a spending cap.
- Decide whether you are building in a new sandbox project or verifying the
  existing project. Do not destroy or recreate the live portfolio environment
  merely to reproduce screenshots.
- Record facts as **verified**, **planned**, or **pending drill**. Do not convert
  an architecture intention into a completed claim.

## Implementation

Write a one-page design brief in your own words using these prompts:

| Decision | SignalDesk answer | Client question it addresses |
|---|---|---|
| Compute | Cloud Run, min 0/max 3 | Can it scale without an always-on server fleet? |
| Data | Zonal Cloud SQL PostgreSQL | Is relational booking data managed and recoverable? |
| Network | Direct VPC egress + private services | Is the database reachable without public IPv4? |
| Secrets | Secret Manager + runtime IAM | Where is the database credential stored and who can read it? |
| Delivery | GitHub Actions + WIF | Can CI deploy without a stored cloud key? |
| IaC | Terraform + versioned GCS state | Can the platform be reproduced and reviewed? |
| Security | Checkov + OPA + Trivy | Are source, proposed changes, and shipped artifacts checked? |
| Reliability | Candidate verification + readiness | Can a bad revision be stopped before normal traffic? |
| Cost | Small SQL tier, scale-to-zero, $10 budget | What prevents accidental lab-scale cost growth? |

Then write the non-goals: high availability, customer authentication, rate
limiting/WAF, a custom domain, IAM database authentication, completed alert
notification drills, and proven backup restoration are later client-dependent
iterations.

## Expected result

You can draw both paths from memory and explain why Cloud Run and Cloud SQL are
managed services connected through the VPC, not virtual machines placed inside
the subnet.

## Screenshot checkpoints

- **SD-00-01** — runtime architecture; caption the public edge, secret boundary,
  and private database path.
- **SD-00-02** — delivery architecture; caption keyless identity, exact-plan
  approval, immutable artifact, and candidate promotion.

These two images come from reviewed source diagrams. Do not screenshot them
from a browser with unrelated tabs or account information visible.

## Security and cost review

The public demo API is an explicit boundary, not an accidental exposure. The
database remains private and the runtime identity receives only runtime roles.
The zonal database and small tier reduce lab cost but do not meet every
production RTO/RPO. Cloud SQL remains the main always-on cost driver.

## Troubleshooting

- If the runtime diagram suggests Cloud Run is inside the VPC, reread the
  Direct VPC egress note in [Architecture decisions](../architecture.md).
- If every component is described as “production grade,” separate verified
  controls from the known gaps in [Acceptance criteria](../acceptance-criteria.md).
- If a screenshot cannot support a sentence-level claim, it is probably
  decorative and should not be in the evidence set.

## Explain it in an interview

> I designed SignalDesk for a small business that needs a secure, repeatable
> cloud launch without enterprise-scale cost. Cloud Run serves the API, Secret
> Manager injects the database credential, and Direct VPC egress reaches a
> private Cloud SQL instance. Terraform owns the platform. GitHub uses OIDC
> federation instead of a JSON key, and separate identities limit blast radius.
> The delivery pipeline evaluates the exact infrastructure plan and promotes an
> immutable candidate only after readiness. I document the gaps separately so
> verified evidence and future hardening are never confused.

## Completion gate

- [ ] I can trace all seven runtime connections without reading the diagram.
- [ ] I can trace the pull-request, infrastructure, and application lanes.
- [ ] I can name the main cost driver and explain why the budget is not a cap.
- [ ] I can distinguish a verified control from a pending operational drill.
- [ ] SD-00-01 and SD-00-02 are reviewed and recorded in the manifest.

[Next: 01 — Workstation and repository](01-workstation-and-repository.md)
