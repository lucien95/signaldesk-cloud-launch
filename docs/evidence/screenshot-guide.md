# Portfolio screenshot capture guide

Screenshots support the written evidence; they do not replace it. Capture each
screen only after understanding which control it proves. Use synthetic booking
data and keep the browser zoom consistent.

## Redaction rules

Never publish:

- billing account identifiers;
- access tokens, authorization headers, cookies, or credential files;
- Secret Manager payload values;
- Terraform state content;
- personal email addresses used for Google Cloud ownership;
- real customer names, email addresses, or booking details.

Raw captures are retained locally in the ignored
`docs/assets/screenshots/raw/` directory. The public files in
`docs/assets/screenshots/` have their browser address bars removed while the
technical console and application content remains unchanged.

The GCP project ID, service name, region, public service URL, service-account
names, GitHub workflow names, revision name, and image digest are useful
technical evidence and may be shown. Crop unrelated browser tabs and personal
profile details where possible.

## Capture set

Create `docs/assets/screenshots/` and use these filenames. Do not take every
screenshot at once; follow the learning order below.

### 00 — Live application overview

**Filename:** `00-live-application-overview.png`

Open the live Cloud Run URL and capture the hero, `Platform ready` indicator,
and platform summary. This is the cover image for the case study. It proves
that the application is publicly reachable from the deployed Cloud Run origin;
the architecture statements inside the UI are orientation, not independent
infrastructure evidence.

### 01 — Customer booking form

**Filename:** `01-customer-booking-form.png`

Show the synthetic customer fields, selected service, price, duration, and the
integration explanation. This introduces the customer journey before any
database write occurs.

### 02 — Live availability

**Filename:** `02-live-availability.png`

Open the live Cloud Run URL and show the service selector, date, and available
time windows. This proves that the deployed revision serves the Next.js
interface and receives API-backed availability. The code and database evidence
establish that FastAPI derives these windows after querying active bookings.

### 03 — Booking confirmation

**Filename:** `03-booking-confirmation.png`

Submit the synthetic booking and capture its reference, appointment time,
status, and request ID. Also show that the selected window is now marked
booked. This connects the database write to an observable request identifier.

### 04 — Database-backed operations result

**Filename:** `04-operations-booking.png`

Open the operations board and search by customer name or booking reference.
Show the same record with its confirmed status. This proves a later API read
can retrieve the record committed by the booking request.

### 05 — Persisted state transition

**Filename:** `05-booking-completed.png`

Mark the booking complete and capture the updated status and summary counts.
This proves the UI, API update route, PostgreSQL transaction, and refreshed
read model complete an end-to-end state change.

### 06 — Cloud Run service summary

**Filename:** `06-cloud-run-service.png`

In Google Cloud Console, open **Cloud Run → signaldesk-dev**. Include the green
status, region, URL, automatic scaling, minimum zero, and maximum three. This
proves the managed runtime and scaling cost guardrail.

### 07 — Immutable revision and traffic

**Filename:** `07-cloud-run-revision.png`

Open the **Revisions** tab and show the serving revision at 100% traffic. In the
details pane include the Artifact Registry image reference, port 8080,
concurrency, timeout, and maximum instances. Do not expose secret values.

### 08a — Runtime identity

**Filename:** `08a-cloud-run-runtime-identity.png`

Capture the selected revision's **Security** tab showing the dedicated runtime
service account. Explain that this identity authorizes the running workload to
reach permitted Google Cloud resources; it is not the PostgreSQL user.

### 08b — Secret reference

**Filename:** `08b-cloud-run-secret-reference.png`

Capture the selected revision's container configuration showing `DB_PASSWORD`
as a Secret Manager reference. Do not open or display the secret payload.
Explain that Cloud Run injects the permitted secret version at runtime and the
application uses its value for PostgreSQL authentication.

### 09 — Private Cloud SQL

**Filename:** `09-cloud-sql-private-network.png`

Open **Cloud SQL → signaldesk-dev → Connections**. Show that public IP is
disabled and private networking is enabled. Crop or obscure unrelated project
metadata. This proves the database is not internet-addressable.

### 10 — Separate Workload Identity pools

**Filename:** `10-workload-identity-pools.png`

Show the active `signaldesk-app` and `signaldesk-infra` pools with their
separate GitHub OIDC providers. This proves application deployment and
infrastructure administration do not share one federated trust boundary.

### 10a — Application delivery OIDC provider

**Filename:** `10a-github-oidc-attribute-mapping.png`

Open the application GitHub Workload Identity provider and show its attribute
mappings and visible condition. Explain that the mapping translates GitHub
token claims into Google attributes and that application impersonation is
restricted to the trusted release workflow on `main` in `development`.

### 10b — Infrastructure delivery OIDC provider

**Filename:** `10b-infrastructure-oidc-provider.png`

Show the infrastructure provider's mappings and visible condition. Explain
that the infrastructure identity trusts the main delivery workflow only in
`infrastructure-plan` or `infrastructure-development`. Use the Terraform source
beside the console screenshots to publish the complete conditions, because the
console text area displays only the currently visible portion.

### 11 — Pull-request gates

**Filename:** `11-pull-request-gates.png`

Open pull request 22 and capture the successful Application quality, Terraform
quality, and DevSecOps security checks. This proves the change was evaluated
before it reached `main`.

### 12 — Main delivery graph

**Filename:** `12-main-delivery.png`

Open Main delivery run 30669346499 and capture the job graph. Include the
quality gates, change selection, infrastructure path, and application
deployment. This is the best single CI/CD overview image.

### 13 — Candidate release evidence

**Filename:** `13-candidate-promotion.png`

Open the Application deployment child job. Show the build, image scan, SBOM,
OIDC authentication, zero-traffic deploy, smoke test, promotion, and final
verification steps. This proves safe application promotion.

### 14 — Infrastructure-only Main delivery

**Filename:** `14-infrastructure-main-delivery.png`

Open the successful infrastructure reconciliation run and capture its job
graph. Show the Terraform plan and exact apply as successful and application
deployment as skipped. Pair this with screenshot 12 to explain path-aware
delivery in both directions.

### 14a — Terraform policy-checked plan

**Filename:** `14a-terraform-policy-checked-plan.png`

Open the infrastructure plan job from the successful reconciliation run. Show
short-lived authentication, remote-state initialization, binary plan creation,
JSON conversion, OPA evaluation, SHA-256 hashing, and protected plan
publication. Do not show raw Terraform state or billing values.

### 14b — Terraform exact-plan apply

**Filename:** `14b-terraform-exact-plan-apply.png`

Open the infrastructure apply job. Show protected-environment execution,
download of the approved plan and checksum, checksum verification, application
of that binary plan, and removal of temporary plan evidence.

### 15a — Request correlation query

**Filename:** `15a-request-correlation-query.png`

In Logs Explorer, filter on the request ID from screenshot 03. Show the
exact service and request ID returning one `request_completed` entry. This
connects the browser-visible correlation value to a backend operating record.

### 15b — Structured request details

**Filename:** `15b-structured-request-log.png`

Expand the matched entry and show `request_id`, method, path, status,
`duration_ms`, message, service, and revision without exposing a request body
or customer data.

### 16 — Monitoring signal

**Filename:** `16-cloud-run-observability.png`

Open Cloud Run observability and show request count, p50/p95/p99 latency, and
error responses over a meaningful time range. Explain that an empty graph is
not evidence; generate a small amount of synthetic traffic first if needed.

### 17 — Budget guardrail

**Filename:** `17-budget-alert.png`

Open **Billing → Budgets & alerts** and show the USD 10 amount with 50%, 90%,
and 100% thresholds. Crop the billing-account identifier. State explicitly
that a budget sends alerts and does not stop resources.

## Documentation pattern for every screenshot

Under each published image, write three short lines:

1. **What you are looking at:** name the console or workflow screen.
2. **What it proves:** identify the engineering control or runtime behavior.
3. **Why the business cares:** connect the control to security, reliability,
   delivery speed, or cost.

Example:

> **Cloud Run revision receiving 100% of traffic.** The application pipeline
> deployed the container by immutable digest, tested it on a zero-traffic
> candidate URL, and promoted it only after readiness, API, and UI checks
> passed. This limits customer exposure to a failed release.

## Architecture assets

These are designed artifacts rather than console screenshots. Publish both;
each has a separate explanatory job.

| Filename | Publication role | What it teaches |
|---|---|---|
| `architecture/signaldesk-runtime-vpc.png` | Primary runtime diagram | Browser-to-Cloud-Run path, the combined Next.js/FastAPI container, Direct VPC egress, Private Service Access, private Cloud SQL, runtime identity, secret injection, observability, reliability, and budget controls |
| `architecture/signaldesk-delivery-pipeline.png` | Primary delivery diagram | Pull-request evidence, protected main, path-aware orchestration, separate OIDC trust boundaries, policy-checked exact-plan Terraform, immutable image delivery, zero-traffic verification, and promotion |

SVG originals live beside the PNG exports so the diagrams remain editable and
can be regenerated at publication resolution.

## Capture inventory

This table is the authoritative record used to assemble the GitHub case study,
Medium article, Substack post, and cloudwithlucien.com portfolio entry.

| Filename | Status | Publication role | Evidence captured |
|---|---|---|---|
| `00-live-application-overview.png` | Captured | Portfolio/Medium cover | Cloud Run URL, application identity, ready signal, and platform summary |
| `01-customer-booking-form.png` | Captured | Product journey | Synthetic form, live service catalog, price/duration, and integration explanation |
| `02-live-availability.png` | Captured | Product journey | API-backed arrival windows and selected 12:00 PM slot |
| `03-booking-confirmation.png` | Captured | Data flow and observability | Booking `SD-64B1C9D1`, confirmed status, booked slot, and create-request ID |
| `04-operations-booking.png` | Captured | Database persistence | Later search retrieved the persisted booking with confirmed status |
| `05-booking-completed.png` | Captured | State transition | Completion update, terminal state, refreshed counts, and update-request ID |
| `06-cloud-run-service.png` | Sanitized and ready | Runtime architecture | Healthy service, region, URL, scaling bounds, request traffic, and latency |
| `07-cloud-run-revision.png` | Sanitized and ready | Release integrity | Revision `signaldesk-dev-00005-nik`, 100% traffic, GitHub deploy identity, image, concurrency, and scaling |
| `08a-cloud-run-runtime-identity.png` | Sanitized and ready | Runtime identity | Dedicated runtime service account, Google-managed encryption, and visible managed-scanning limitation |
| `08b-cloud-run-secret-reference.png` | Sanitized and ready | Secret delivery | `DB_PASSWORD` references `signaldesk-dev-database-password:latest`; database name, user, connection name, and environment are non-secret configuration |
| `09-cloud-sql-private-network.png` | Sanitized and ready | Network security | PostgreSQL 18, Private Service Access, dedicated VPC, internal address, disabled public IP, port 5432, and SSL-only connections |
| `10-workload-identity-pools.png` | Sanitized and ready | Identity separation | Active application and infrastructure pools with separate GitHub OIDC providers |
| `10a-github-oidc-attribute-mapping.png` | Sanitized and ready | Keyless application delivery | Application provider mappings plus `main`, deployment workflow, called workflow, and `development` restrictions |
| `10b-infrastructure-oidc-provider.png` | Sanitized and ready | Keyless infrastructure delivery | Infrastructure provider mappings plus `main`, delivery workflow, plan/apply environment restrictions |
| `11-pull-request-gates.png` | Sanitized and ready | Shift-left controls | Merged PR 22 with six successful application, dependency, Terraform, IaC, container, and SBOM jobs |
| `12-main-delivery.png` | Sanitized and ready | Delivery orchestration | Successful trusted-main run, repeated quality gates, path selection, deliberately skipped infrastructure plan/apply, and verified application deployment |
| `13-candidate-promotion.png` | Sanitized and ready | Safe release | Build once, Trivy, SBOM, short-lived credentials, digest publication, zero-traffic test, promotion, and public verification |
| `14-infrastructure-main-delivery.png` | Sanitized and ready | Infrastructure delivery path | Successful quality gates, Terraform plan/apply, and deliberately skipped application deployment |
| `14a-terraform-policy-checked-plan.png` | Sanitized and ready | IaC proposal governance | Trusted main revision, checksum-verified OPA, OIDC, locked remote state, binary plan, JSON policy input, real-plan policy enforcement, hash, and protected publication |
| `14b-terraform-exact-plan-apply.png` | Sanitized and ready | IaC execution governance | Planned revision, OIDC, same locked state, approved plan/checksum download, integrity verification, exact binary apply, and evidence cleanup |
| `15a-request-correlation-query.png` | Sanitized and ready | Observability correlation | Exact service/request-ID query returns one `request_completed` record |
| `15b-structured-request-log.png` | Sanitized and ready | Structured logging | `request_completed`, exact request ID, POST booking path, HTTP 201, 180.78 ms duration, INFO severity, and Cloud Run resource |
| `16-cloud-run-observability.png` | Covered by screenshot 06 | Reliability | Request, latency-percentile, end-to-end latency, and latency-breakdown signals after synthetic traffic |
| `17-budget-alert.png` | Sanitized and ready | Cost governance | Monthly USD 10 specified budget, project scope, current-spend tracking, and 50%/90%/100% alert thresholds |

### Correlation record for the captured booking

- Synthetic customer: `Avery Johnson` / `avery@example.com`.
- Booking reference: `SD-64B1C9D1`.
- Service: Repair assessment.
- Scheduled time: 2026-08-03 at 12:00 PM EDT.
- Create-request ID: `5c59ba5f-45c7-4670-aecb-7b30a5bd7e00`.
- Completion-update request ID: `af4bbcdc-50a1-4355-a28e-ef76df49df59`.

The raw Cloud Run and Google Cloud captures remain locally available for audit.
The public copies remove browser, free-trial, billing-account, and personal
profile chrome while retaining the service controls, scaling values, metrics,
identity, networking, logging, and budget evidence.

The raw budget capture exposes the billing-account identifier in the browser
URL. That identifier must be removed before public upload. Preserve the budget
name, monthly period, project scope, USD 10 amount, and 50%/90%/100% thresholds.
The Terraform-managed budget configures notifications only; do not describe it
as a hard spending cap or automatic resource shutdown.

The runtime-identity capture also shows that Google-managed threat detection
and Container Scanning API insights are disabled. Do not crop out this fact or
claim those controls are enabled. Explain that the implemented release control
is Trivy image scanning plus a CycloneDX SBOM in GitHub Actions; managed
registry scanning is a documented hardening option.

The secret-reference capture intentionally shows the secret resource name and
selected version alias, not the payload. `DB_USER`, `DB_NAME`, and the instance
connection name identify the connection target but do not authenticate by
themselves. The password value remains outside the image, repository, and
GitHub configuration.

Main delivery run 30669346499 is application-only evidence. Change detection
selected the application path, so the infrastructure plan and apply jobs are
correctly shown as skipped. Terraform validation still ran. Use the earlier
infrastructure reconciliation run for exact-plan/apply evidence; do not claim
that run 30669346499 applied Terraform.

The screenshot showing a failed search for the create-request ID is retained as
optional teaching evidence, not part of the primary publication sequence. It
demonstrates that a request ID is an observability identifier, while a booking
reference is a business identifier. Use the working name
`learning-request-id-vs-booking-id.png` if that image is included.
