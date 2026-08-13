# Screenshot asset library

This directory contains only reviewed, sanitized images that are safe to commit
and publish. Keep original full-screen captures outside the repository so an
accidental commit cannot expose account, billing, credential, or customer data.

## Directory map

| Folder | Chapter |
|---|---|
| `00-orientation/` | Architecture and project orientation |
| `01-workstation/` | Local tools and repository structure |
| `02-gcp-project/` | GCP project, billing status, and ADC context |
| `03-bootstrap/` | State bucket, bootstrap plan, and outputs |
| `04-github-oidc/` | GitHub environments, variables, and WIF |
| `05-infrastructure-devsecops/` | PR gates, policy, plan approval, and private SQL |
| `06-release/` | Delivery graph, image digest, and Cloud Run traffic |
| `07-runtime-evidence/` | API transaction, correlated logs, and uptime check |
| `08-operations-publication/` | Budget, backups, and public case study |

The folders may be created as screenshots become available. Git does not track
empty folders.

## Capture workflow

1. Find the screenshot ID in `../screenshot-manifest.yml`.
2. Perform the chapter checkpoint and capture the original outside Git.
3. Crop and redact it using `../screenshot-standards.md`.
4. Save it here using the manifest's exact folder and filename.
5. Change its manifest status from `planned` to `captured`, then `sanitized`
   only after a second review.
6. Add the image and its caption to the chapter.
7. Use `published` only after confirming the public page contains the approved
   version.

Do not silently replace evidence. If a deployment changes, capture a new image,
review it, and record the change in Git history.
