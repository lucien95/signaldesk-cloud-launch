# 01 — Prepare the workstation and understand the repository

## Outcome

You have the repository open in VS Code, the required tools installed, local
tests passing, and a mental model for which folders are edited during normal
application, infrastructure, policy, or documentation work.

## Business reason

A reproducible workstation reduces “works on my machine” failures and shortens
client handoff. A clear repository boundary also prevents routine application
changes from accidentally touching the one-time cloud trust bootstrap.

## Concepts

| Path | Responsibility | Touch it when | Avoid changing it when |
|---|---|---|---|
| `app/` | FastAPI source, tests, dependencies, Docker image | API behavior or runtime package changes | Editing cloud IAM or networking |
| `terraform/bootstrap/` | State bucket, WIF pools, deploy identities | Trust root or CI identity design changes | Normal application releases |
| `terraform/environments/dev/` | VPC, SQL, secrets, Cloud Run, monitoring, budget | Platform configuration changes | Only changing documentation |
| `.github/workflows/` | PR validation and main delivery orchestration | Delivery behavior or checks change | Storing environment values or credentials |
| `policy/terraform/` | SignalOps OPA rules and unit tests | Business-specific plan policy changes | General scanner configuration |
| `security/` and `.checkov.yml` | Pinned security tools and Checkov behavior | Scanner upgrade or reviewed exception | Hiding unexplained failures |
| `scripts/` | Checksum-verified tool installation and policy adapter | Tool version/checksum or automation changes | Replacing normal Terraform modules |
| `docs/` | Architecture, runbooks, evidence, and this workshop | Design/evidence changes | Treating screenshots as source of truth |
| `.venv/`, `.security-venv/`, `.tools/`, `.terraform/` | Generated local state and tool caches | Usually created by commands | Editing or committing manually |

The workflows call the Makefile, Terraform roots, scanner configuration,
policies, and scripts. The repository variables provide environment-specific
identifiers at runtime. No workflow reads values from a committed `.env` or
`terraform.tfvars` file.

## Before you run anything

Install Git, VS Code, Google Cloud CLI, Terraform, Docker, Python 3, GitHub CLI,
`jq`, and Make. Docker Desktop must be running for image tests. Use Terraform
1.15.8 when reproducing the authoritative delivery plan because that is the
version pinned by the pipeline.

## Implementation

Clone and open the repository:

```bash
mkdir -p ~/Documents/gcp-projects
cd ~/Documents/gcp-projects
git clone https://github.com/lucien95/signaldesk-cloud-launch.git
cd signaldesk-cloud-launch
code .
```

If it is already cloned, do not clone a second copy. Confirm the remote and
branch instead:

```bash
git remote -v
git status -sb
```

Capture a bounded tool inventory:

```bash
gcloud version
terraform version
docker --version
python3 --version
gh --version
jq --version
make --version | head -n 1
```

Install the local development environment and run the fast checks:

```bash
make install
make lint
make test
make terraform-check
```

Run the full security suite when you are ready for downloads and container
work:

```bash
make security-check
make trivy-image
```

Optional local API exercise:

```bash
make run
```

In a second terminal:

```bash
curl http://localhost:8080/health/live
curl http://localhost:8080/health/ready
```

The local test setup uses SQLite; it proves application behavior, not private
Cloud SQL connectivity.

## Expected result

- Git reports the intended GitHub remote and expected branch.
- Ruff, Bandit, pytest, Terraform format/validate, Checkov, OPA, actionlint,
  dependency audit, and Trivy complete without unexplained failures.
- Generated directories remain untracked.
- You can point to the file responsible for a code test, Terraform plan policy,
  image scan, and main deployment.

## Screenshot checkpoints

- **SD-01-01** — VS Code Explorer with this repository only and the major
  folders visible.
- **SD-01-02** — a fresh, bounded terminal containing only tool names and
  versions.

Do not include a terminal containing authentication history. Crop the macOS
username and unrelated workspace names when they do not add evidence.

## Security and cost review

Local virtual environments and Terraform caches are ignored because they may
contain machine-specific or sensitive material. Version files and lock files
are reviewed; generated credentials and state are not committed. The local
checks do not create GCP resources, so this chapter adds no cloud runtime cost.

## Troubleshooting

- `code: command not found`: in VS Code, install the `code` shell command or
  open the folder through **File → Open Folder**.
- Docker scan cannot connect: start Docker Desktop, then rerun the image step.
- Terraform version differs: install/select 1.15.8 before comparing a local
  plan to pipeline behavior.
- A scanner downloads slowly: let the checksum-verified installer finish; do
  not replace it with an unpinned binary.
- Generated folders appear in Git: stop and inspect `.gitignore` before adding
  files.

## Explain it in an interview

> I kept application, trust bootstrap, repeatable environment infrastructure,
> policy, pipeline, and documentation concerns visibly separate. The Makefile
> gives developers the same entry points used by CI, while lock files and
> pinned scanner installers make tool behavior reproducible. Generated state,
> credentials, and local environments are ignored rather than used as source
> configuration.

## Completion gate

- [ ] I can explain every top-level folder and name when it should change.
- [ ] Local application and Terraform checks pass.
- [ ] I know local SQLite readiness does not prove Cloud SQL readiness.
- [ ] No credential, `.env`, state, plan, or real `terraform.tfvars` is tracked.
- [ ] SD-01-01 and SD-01-02 are sanitized and recorded.

[Previous: 00 — Orientation](00-orientation.md) · [Next: 02 — GCP project, billing, and ADC](02-gcp-project-billing-and-adc.md)
