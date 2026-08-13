# 06 — Perform the first safe application release

## Outcome

The pipeline builds one application image, blocks serious findings, records an
SBOM, publishes the image, deploys its immutable digest with zero normal
traffic, smoke-tests the candidate, and then promotes that exact revision.

## Business reason

A green container build does not prove a safe release. A client needs to know
which artifact is serving, whether it was scanned, and whether a failed
candidate can be stopped before customers are moved to it.

## Concepts

The release chain is:

```text
trusted main commit
  -> build the image once
  -> Trivy HIGH/CRITICAL gate
  -> CycloneDX SBOM
  -> short-lived application WIF credential
  -> push commit-tagged image
  -> resolve sha256 digest
  -> deploy digest with --no-traffic and candidate tag
  -> test candidate /health/ready
  -> send 100% traffic to the verified revision
  -> verify the public readiness endpoint
```

A tag is a convenient label and can be moved. A digest identifies exact image
content. “Build once” prevents the scanned bytes and deployed bytes from coming
from separate builds.

Cloud Run creates an immutable revision for the new template. `--no-traffic`
keeps normal users on the previous serving revision. The candidate tag provides
a URL for verification before promotion.

## Before you run anything

- The Chapter 05 infrastructure apply must have created Artifact Registry,
  Cloud Run, runtime IAM, the database, and the secret.
- The `development` GitHub environment and application WIF values must match
  Chapter 04.
- The application change must pass all trusted-main gates.
- Confirm the new image does not contain local `.env`, credential, or state
  files; the Docker build context is `app/`.

## Implementation

### 1. Trigger the release

An application or relevant workflow change merged to `main` automatically
selects the application lane. A manual **Run workflow** executes both paths and
should be used deliberately, not as a substitute for understood change
detection.

Open **Actions → Main delivery** and follow the job graph. The application job
waits for application, Terraform, and security quality gates. If the same
commit changes development infrastructure, it also waits for successful plan
and apply.

### 2. Inspect the release evidence

Open **Scan, release, verify, and promote** and confirm:

- the image was built once with the trusted commit SHA as its tag;
- Trivy returned no blocking fixed HIGH/CRITICAL vulnerability or secret;
- `signaldesk-release.cdx.json` was uploaded as a 30-day workflow artifact;
- GitHub authenticated through the application WIF provider;
- the pushed tag resolved to a non-empty `sha256:` digest;
- Cloud Run deployed that digest with zero traffic;
- candidate readiness passed before traffic promotion;
- public readiness passed after promotion.

### 3. Verify the deployed artifact independently

```bash
export PROJECT_ID="kloudwithlucien-503200"
export REGION="us-east1"
export SERVICE="signaldesk-dev"

export REVISION="$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format='value(status.latestReadyRevisionName)')"

gcloud run revisions describe "${REVISION}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format='value(spec.containers[0].image)'

gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format='yaml(status.traffic)'
```

The image URI must contain `@sha256:` and the serving revision must receive
100% of normal traffic after verification.

### 4. Understand the failure boundary

If the candidate readiness test fails, the promotion step does not run and the
prior revision keeps normal traffic. That safety property is implemented, but
the acceptance register distinguishes it from a deliberately executed
known-bad candidate drill. Do not claim the drill until traffic evidence has
been captured.

## Expected result

- The job graph shows quality gates before deployment.
- The release SBOM is downloadable within its retention window.
- Artifact Registry identifies the image by commit tag and SHA-256 digest.
- Cloud Run serves the digest-pinned revision at 100% after candidate success.
- No application job has infrastructure state or network-administration access.

## Screenshot checkpoints

- **SD-06-01** — the successful main-delivery job graph in dependency order.
- **SD-06-02** — Artifact Registry details showing commit tag and digest.
- **SD-06-03** — Cloud Run revision/traffic view after promotion.

Crop project numbers, unrelated artifacts, account avatars, and temporary
candidate URLs when they do not support the claim.

## Security and cost review

The application service account has Artifact Registry writer and Cloud Run
developer permissions. It cannot change the WIF provider, Terraform state,
network, or SQL platform. Actions and image inputs are pinned, downloaded tools
are checksum-verified, and the base image is digest-pinned. Old untagged images
are cleaned up, and Cloud Run can scale to zero with a maximum of three
instances.

## Troubleshooting

- Application job is skipped: inspect the `Select delivery paths` output and
  changed file paths in `delivery.yml`.
- WIF authentication fails: return to Chapter 04 and compare the `development`,
  delivery workflow, reusable workflow, branch, and immutable ID claims.
- Image push is denied: verify the app deploy service account and Artifact
  Registry writer role, not the infrastructure account.
- Candidate is not ready: inspect the candidate revision logs and database
  readiness; do not manually promote it.
- Digest output is empty: reject the release and inspect Artifact Registry
  authentication/push before deployment.

## Explain it in an interview

> The pipeline builds a release candidate once, scans that exact local image,
> and generates a CycloneDX SBOM. After keyless authentication it pushes the
> commit-tagged image, resolves the registry digest, and deploys the digest to a
> zero-traffic Cloud Run revision. It calls the database-backed readiness
> endpoint on the candidate URL, and only a passing revision receives 100%
> traffic. A failed candidate therefore leaves the prior revision serving.

## Completion gate

- [ ] I can explain tag versus digest and why the build happens once.
- [ ] The SBOM, scan, digest resolution, candidate test, and promotion are visible.
- [ ] The serving Cloud Run image contains `@sha256:`.
- [ ] I can distinguish implemented failure safety from a completed failure drill.
- [ ] SD-06-01 through SD-06-03 are sanitized and recorded.

[Previous: 05 — Infrastructure and DevSecOps](05-infrastructure-and-devsecops.md) · [Next: 07 — Runtime verification](07-runtime-verification.md)
