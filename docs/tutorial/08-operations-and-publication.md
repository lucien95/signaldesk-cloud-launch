# 08 — Review operations, close evidence gaps, and publish

## Outcome

You verify cost and recovery controls, maintain an honest gap register, assemble
sanitized proof assets, and publish a case study whose claims link back to
architecture, source, live behavior, and evidence.

## Business reason

A launch is not finished when the endpoint responds. A client needs cost
visibility, backup and rollback expectations, operational ownership, and
documentation that another engineer can follow. Honest gaps are more valuable
than untested reliability claims.

## Concepts

Separate four evidence levels:

1. **Configured** — code or console shows a control exists.
2. **Observed** — the live system shows the control operating.
3. **Drilled** — a controlled failure/recovery exercise proves the response.
4. **Published** — sanitized evidence and context are available to an external
   reader.

A listed backup is configured/observed but not a proven restore. An old Cloud
Run revision exists but does not prove a ten-minute rollback. An uptime check
does not prove an alert notification reached a human.

## Before you run anything

- Complete [Acceptance criteria](../acceptance-criteria.md) and mark pending
  drills honestly.
- Read [Cost model](../cost-model.md), [Security model](../security.md), and the
  [rollback runbook](../runbooks/rollback.md).
- Keep private originals outside Git and work only from sanitized copies.
- Do not alter or publish the existing SignalOps page until this package has
  been reviewed.

## Implementation

### 1. Verify cost controls

```bash
export PROJECT_ID="kloudwithlucien-503200"
export REGION="us-east1"
export SERVICE="signaldesk-dev"
export BILLING_ACCOUNT="$(gcloud billing projects describe "${PROJECT_ID}" \
  --format='value(billingAccountName.basename())')"

gcloud billing budgets list \
  --billing-account="${BILLING_ACCOUNT}" \
  --filter='displayName="SignalDesk dev monthly budget"' \
  --format='table(displayName,amount.specifiedAmount.currencyCode,amount.specifiedAmount.units,thresholdRules.thresholdPercent)'

gcloud artifacts repositories describe signaldesk \
  --project="${PROJECT_ID}" --location="${REGION}" \
  --format='yaml(format,cleanupPolicies)'

gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format='yaml(spec.template.metadata.annotations,spec.template.spec.containerConcurrency)'
```

Expect the $10 monthly notification budget with 50%, 90%, and 100% thresholds,
untagged image cleanup, Cloud Run minimum zero, and maximum three. Never show
the billing-account value in published output.

### 2. Verify recovery inputs without claiming a recovery drill

```bash
gcloud sql backups list \
  --project="${PROJECT_ID}" --instance=signaldesk-dev --limit=10 \
  --format='table(id,status,startTime,endTime,type)'

gcloud run revisions list \
  --project="${PROJECT_ID}" --region="${REGION}" --service="${SERVICE}" \
  --format='table(metadata.name,status.conditions[0].status,metadata.creationTimestamp)'
```

Record successful backups and available revisions. Restore into a separate
instance and timed rollback are intentional later drills because both mutate
live state and require a controlled window.

### 3. Maintain the gap register

Keep these pending until each has direct evidence:

- known-bad candidate rejected while prior traffic remains unchanged;
- Cloud Run rollback completed inside ten minutes;
- alert policy and notification channel receive a controlled 5xx event;
- Cloud SQL backup restored to a separate instance and validated;
- documented load test with p95 latency;
- final destroy plus orphan-resource inventory.

Each completed drill should produce a dated record with scenario, hypothesis,
commands/actions, timestamps, result, cleanup, and sanitized evidence.

### 4. Prepare screenshot evidence

For every entry in [the manifest](screenshot-manifest.yml):

1. perform the real checkpoint;
2. capture the full original outside Git;
3. crop to the smallest useful region;
4. redact using [the standards](screenshot-standards.md);
5. save under `assets/<chapter>/` with the exact filename;
6. update status to `captured`, then `sanitized` after review;
7. add a caption that states action, result, and significance.

Never manufacture a screenshot from expected output. A screenshot is dated
evidence and can become stale after infrastructure or pipeline changes.

### 5. Package the architecture and case study

Use the reviewed SVGs directly on the website. Import
`../diagrams/signaldesk-architecture.drawio` into Lucidchart when a stakeholder
needs a Lucid-editable copy, then preserve the repository source as the
version-controlled master.

The public case study should contain:

- business problem and target client;
- runtime and CI/CD architecture diagrams;
- design decisions and tradeoffs;
- Terraform/IaC and identity model;
- DevSecOps and safe-release sequence;
- security, observability, and cost controls;
- measured results with dates;
- explicit known gaps/next drills;
- links to live API, source, architecture, verification, and runbooks.

### 6. Perform a final publication review

Before pushing documentation or updating the SignalOps site:

```bash
git status --short
git diff --check
git diff --stat
```

Search staged material for credential and billing patterns, inspect every image
at full resolution, validate all relative links, and ask a second reviewer to
check the evidence if available. Publish documentation through the same pull
request and checks process as code.

## Expected result

- Budget thresholds and bounded scaling are verified, with the budget described
  as a notification control rather than a cap.
- Successful backups and prior revisions exist, but restore/rollback claims
  remain pending until drilled.
- Every public screenshot has an ID, claim, caption, redaction review, and
  manifest status.
- The case study tells a business story while linking engineering claims to
  reproducible evidence.

## Screenshot checkpoints

- **SD-08-01** — budget name, amount, and thresholds with billing identifiers
  cropped.
- **SD-08-02** — successful backup status and timestamps without private
  addresses.
- **SD-08-03** — final public case study showing live, source, architecture, and
  verification links; crop admin/session details.

## Security and cost review

Screenshots are an exfiltration path: browser profiles, OAuth codes, billing
IDs, account emails, tokens, private addresses, state, logs, and real customer
data may appear around the intended proof. Redaction is a release gate. Keep
Cloud SQL runtime and backup storage under review; alerts do not automatically
stop resources. Teardown is a deliberate final operation, never a documentation
step performed merely to obtain a screenshot.

## Troubleshooting

- An image proves only configuration, not behavior: move the claim to
  configured/observed and schedule a drill.
- A screenshot needs heavy redaction: recapture a narrower, formatted output
  rather than painting over half the screen.
- Public docs conflict with Terraform: update docs or implementation before
  publishing; Terraform/workflows remain source of truth.
- The case study becomes a tool list: lead with client problem, risk, decision,
  outcome, and evidence; name tools where they explain a control.
- Costs exceed expectation: inspect SQL uptime/tier/storage, logs, artifacts,
  Cloud Run instances, backups, and egress before changing the budget number.

## Explain it in an interview

> I treated evidence maturity explicitly. Configuration proves a control was
> declared, observation proves it operated, and a controlled drill proves the
> team can recover. SignalDesk has keyless delivery, private database access,
> exact-plan apply, immutable candidate promotion, structured correlation,
> uptime checks, backups, and a $10 notification budget. I did not claim paging,
> timed rollback, restore, load performance, or teardown until those drills had
> direct evidence. The public case study links each major claim to sanitized,
> reproducible proof.

## Completion gate

- [ ] I can explain configured versus observed versus drilled versus published.
- [ ] Budget, cleanup, backup, and revision controls were inspected.
- [ ] All pending drills remain visibly pending unless supported by evidence.
- [ ] Every screenshot passes the manifest and redaction checklist.
- [ ] Architecture, source, live endpoint, and verification links are present.
- [ ] Documentation passed review before publication.

[Previous: 07 — Runtime verification](07-runtime-verification.md) · [Workshop index](README.md)
