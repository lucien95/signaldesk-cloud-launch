# 07 — Verify the running system with end-to-end evidence

## Outcome

You prove the service is live, database-ready, able to persist a synthetic
booking, traceable through structured logs, connected to private Cloud SQL,
and checked by Cloud Monitoring.

## Business reason

Deployment success is an automation event, not proof that a customer's workflow
works. Runtime verification connects a real API request to data persistence,
networking, secrets, identity, logs, and health monitoring.

## Concepts

- `/health/live` asks whether the application process responds.
- `/health/ready` executes `SELECT 1` and asks whether the application can use
  its database dependency.
- A request ID links the client interaction to one structured log record.
- Cloud Run Direct VPC egress carries private-range traffic into the subnet;
  Cloud Run itself is still managed serverless compute.
- Private Service Access peers the VPC with the Google-managed service producer
  network that hosts the Cloud SQL private address.
- Secret metadata and IAM prove wiring without revealing the secret value.

## Before you run anything

Use the complete [manual post-deployment verification lab](../manual-verification-lab.md)
as the canonical command source. The focused path below produces the three
chapter screenshots. Use only `example.com` data and do not run apply, destroy,
traffic changes, secret access, or restore commands during this inspection.

```bash
export PROJECT_ID="kloudwithlucien-503200"
export REGION="us-east1"
export SERVICE="signaldesk-dev"
export SERVICE_URL="$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format='value(status.url)')"
```

## Implementation

### 1. Check liveness and readiness

```bash
curl --fail --silent --show-error "${SERVICE_URL}/health/live" | jq .
curl --fail --silent --show-error "${SERVICE_URL}/health/ready" | jq .
```

Liveness without readiness usually indicates a dependency problem rather than
a crashed web process.

### 2. Execute a synthetic database transaction

```bash
export REQUEST_ID="tutorial-$(date -u +%Y%m%dT%H%M%SZ)"

export BOOKING_JSON="$(curl --fail --silent --show-error \
  -X POST "${SERVICE_URL}/api/v1/bookings" \
  -H 'content-type: application/json' \
  -H "x-request-id: ${REQUEST_ID}" \
  -d '{
    "customer_name": "SignalOps Tutorial",
    "customer_email": "signaldesk-tutorial@example.com",
    "service": "Cloud architecture review",
    "scheduled_at": "2026-12-15T15:00:00Z"
  }')"

echo "${BOOKING_JSON}" | jq .
export BOOKING_ID="$(echo "${BOOKING_JSON}" | jq -r '.id')"

curl --fail --silent --show-error \
  "${SERVICE_URL}/api/v1/bookings/${BOOKING_ID}" | jq .

curl --fail --silent --show-error \
  -X PATCH "${SERVICE_URL}/api/v1/bookings/${BOOKING_ID}/status" \
  -H 'content-type: application/json' \
  -d '{"status":"completed"}' | jq .
```

The API intentionally has no delete endpoint. The record must be unmistakably
synthetic.

### 3. Correlate the request in Cloud Logging

```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=${SERVICE} AND jsonPayload.request_id=\"${REQUEST_ID}\"" \
  --project="${PROJECT_ID}" --freshness=30m --limit=10 \
  --format='table(timestamp,resource.labels.revision_name,jsonPayload.method,jsonPayload.path,jsonPayload.status,jsonPayload.duration_ms,jsonPayload.message)'
```

Expect method `POST`, the booking path, status 201, duration, the serving
revision, and the same request ID. Request bodies are deliberately not logged.

### 4. Verify monitoring and the private data path

```bash
gcloud monitoring uptime list-configs \
  --project="${PROJECT_ID}" \
  --format='table(displayName,period,timeout,httpCheck.path,httpCheck.useSsl)'

gcloud sql instances describe signaldesk-dev \
  --project="${PROJECT_ID}" \
  --format='yaml(state,region,databaseVersion,settings.ipConfiguration.ipv4Enabled,settings.ipConfiguration.privateNetwork,settings.backupConfiguration)'

gcloud secrets versions list signaldesk-dev-database-password \
  --project="${PROJECT_ID}" \
  --format='table(name,state,createTime)'

gcloud secrets get-iam-policy signaldesk-dev-database-password \
  --project="${PROJECT_ID}" \
  --format='table(bindings.role,bindings.members)'
```

Do not run `gcloud secrets versions access`. The goal is to verify enabled
version metadata and runtime authorization, never the payload.

For the full VPC, IAM blast-radius, immutable revision, no-drift, and state
checks, complete checkpoints 0–11 in the manual lab.

## Expected result

- Liveness returns `ok`; readiness returns `ready`.
- Booking creation returns a UUID and the stored record can be retrieved and
  changed from `confirmed` to `completed`.
- The request ID finds a structured HTTP 201 log on the serving revision.
- The uptime check calls `/health/ready` over HTTPS every 60 seconds.
- Cloud SQL public IPv4 is false and a private network is configured.
- An enabled secret version exists and only the runtime identity has the
  intended accessor role.

## Screenshot checkpoints

- **SD-07-01** — bounded output for live/ready and the synthetic create,
  retrieve, and status update.
- **SD-07-02** — one correlated log result with request ID, method, path, status,
  duration, and revision.
- **SD-07-03** — uptime check configuration and current result.

Never include real customer data, authorization headers, secret values, private
IP addresses, or unrelated logs.

## Security and cost review

The public API has no customer authentication or rate limiting; this is an
explicit development-demo risk. The database is not public, secrets are not
logged, and the runtime account does not receive deployment permissions.
Structured log volume and 60-second monitoring contribute to cost, so retention
and ingestion belong in the seven-day cost review.

## Troubleshooting

- Liveness passes but readiness fails: inspect the runtime service account,
  secret version/IAM, Direct VPC egress, private service connection, and SQL
  status in that order.
- POST succeeds but log lookup is empty: check the exact request ID, freshness
  window, service name, project, and JSON payload field spelling.
- SQL output includes a public address: stop and reconcile Terraform before
  claiming the private-data-path control.
- Uptime check exists but no alert arrives: expected currently. The check is
  configured, but alert policy, notification channel, and controlled 5xx drill
  remain pending.

## Explain it in an interview

> I verified more than the deployment status. Liveness proved the process was
> responsive, while readiness executed a database query. I sent a synthetic
> booking through create, retrieve, and update, then used its request ID to find
> the structured 201 log and serving revision. I separately verified private
> SQL networking, secret metadata and IAM without reading the secret, and the
> readiness uptime check. That ties the customer transaction to compute,
> identity, secrets, network, database, logging, and monitoring evidence.

## Completion gate

- [ ] I can explain live versus ready and why both are needed.
- [ ] One synthetic transaction persisted and changed state.
- [ ] The request is traceable by request ID without body/customer logging.
- [ ] Private SQL, secret wiring, and uptime configuration were verified.
- [ ] I do not claim completed paging from an uptime check alone.
- [ ] SD-07-01 through SD-07-03 are sanitized and recorded.

[Previous: 06 — First safe release](06-first-safe-release.md) · [Next: 08 — Operations and publication](08-operations-and-publication.md)
