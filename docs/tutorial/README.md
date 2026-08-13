# Build SignalDesk from zero to verified deployment

This workshop is the reproducible version of the SignalDesk portfolio project.
It is written for a reader starting with an empty Google Cloud project and a
GitHub repository. Each chapter combines implementation, business reasoning,
security review, screenshot evidence, troubleshooting, and an interview-ready
explanation.

The workshop does not treat a green deployment as sufficient. A reader is done
only after they can reproduce the architecture, validate the important trust
boundaries, and distinguish completed evidence from planned reliability work.

For a fresh build, follow every chapter in order. For the already deployed
reference environment, repeat only the read-only verification and screenshot
steps; do not recreate or destroy live resources to make the guide look new.

## Workshop outcome

The reader will build and verify:

- a FastAPI booking API on Cloud Run;
- private Cloud SQL for PostgreSQL connectivity through Direct VPC egress;
- Secret Manager runtime injection;
- Terraform-managed infrastructure and a versioned GCS state backend;
- keyless GitHub Actions authentication through Workload Identity Federation;
- separate infrastructure, application-deployment, and runtime identities;
- Checkov, OPA, Trivy, Bandit, pip-audit, actionlint, and test gates;
- exact Terraform plan approval and apply;
- immutable image deployment, zero-traffic smoke testing, and promotion;
- structured logging, uptime checks, backups, and budget alerts;
- sanitized evidence suitable for a public portfolio.

## Use the workshop in order

| Chapter | Build milestone | Primary evidence |
|---|---|---|
| [00 — Orientation](00-orientation.md) | Understand the business problem and architecture | Architecture diagrams |
| [01 — Workstation and repository](01-workstation-and-repository.md) | Reproducible local toolchain | Version and repository screenshots |
| [02 — GCP project, billing, and ADC](02-gcp-project-billing-and-adc.md) | Correct human and quota context | Project and billing verification |
| [03 — Bootstrap the trust root](03-bootstrap-trust-root.md) | State bucket, WIF, and deploy identities | Terraform plan, outputs, and GCP resources |
| [04 — Connect GitHub without keys](04-github-keyless-authentication.md) | Environments, variables, OIDC conditions | GitHub and WIF configuration |
| [05 — Build infrastructure and security gates](05-infrastructure-and-devsecops.md) | Runtime platform and policy gates | PR checks and reviewed Terraform plan |
| [06 — Perform the first safe release](06-first-safe-release.md) | Immutable candidate and promotion | Delivery jobs, digest, and traffic |
| [07 — Verify runtime evidence](07-runtime-verification.md) | Database transaction and correlated logs | API, Cloud SQL, IAM, and log evidence |
| [08 — Operate, improve, and publish](08-operations-and-publication.md) | Cost/recovery review and portfolio package | Gap register and sanitized proof assets |

## Standard chapter format

Every chapter uses the same sequence:

1. **Outcome** — the concrete milestone.
2. **Business reason** — why a client would pay for it.
3. **Concepts** — what the cloud components do.
4. **Before you run anything** — prerequisites and safety checks.
5. **Implementation** — commands or console actions.
6. **Expected result** — what success actually looks like.
7. **Screenshot checkpoints** — the minimum useful visual evidence.
8. **Security and cost review** — risks, controls, and tradeoffs.
9. **Troubleshooting** — likely failures and diagnostic direction.
10. **Explain it in an interview** — a concise engineering narrative.
11. **Completion gate** — evidence required before continuing.

## Screenshot system

Read [Screenshot standards](screenshot-standards.md) before capturing anything.
The [screenshot manifest](screenshot-manifest.yml) is the inventory and review
record. A screenshot is not publishable until its status is `sanitized` and its
redaction checklist is complete.

The [asset library guide](assets/README.md) defines where reviewed images go
and how a private original becomes a version-controlled public proof asset.

Screenshots belong under:

```text
docs/tutorial/assets/
├── 00-orientation/
├── 01-workstation/
├── 02-gcp-project/
├── 03-bootstrap/
├── 04-github-oidc/
├── 05-infrastructure-devsecops/
├── 06-release/
├── 07-runtime-evidence/
└── 08-operations-publication/
```

Use IDs and filenames from the manifest. Do not save random names such as
`Screenshot 2026-07-27 at 8.42.13 PM.png`.

## Evidence versus instructions

The workshop contains two different kinds of image:

- **instruction screenshot** — shows where to click or what setting to choose;
- **evidence screenshot** — proves a control or deployment result.

One image can sometimes serve both purposes, but its caption must say which
claim it supports. Avoid decorative screenshots that add no learning or proof.

## Canonical supporting documents

- [Architecture decisions](../architecture.md)
- [Production-style deployment guide](../deployment.md)
- [DevSecOps walkthrough](../devsecops.md)
- [Security model](../security.md)
- [Cost model](../cost-model.md)
- [Acceptance criteria](../acceptance-criteria.md)
- [Manual post-deployment verification lab](../manual-verification-lab.md)
- [Deployment verification record](../evidence/deployment-verification.md)

The workshop explains and sequences these sources. Terraform and workflow files
remain the implementation source of truth; screenshots are evidence, not
configuration.
