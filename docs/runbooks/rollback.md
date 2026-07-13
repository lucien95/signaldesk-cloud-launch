# Cloud Run rollback runbook

## Trigger

Rollback when a new revision causes customer-visible errors, readiness failure,
or latency beyond the agreed release threshold.

## Procedure

1. Confirm the incident and record the current revision and deployment commit.
2. List revisions:

   ```bash
   gcloud run revisions list --service signaldesk-dev --region us-east1
   ```

3. Send all traffic to the last known-good revision:

   ```bash
   gcloud run services update-traffic signaldesk-dev \
     --region us-east1 \
     --to-revisions LAST_KNOWN_GOOD=100
   ```

4. Run `/health/ready` and the booking smoke test.
5. Confirm error rate and latency return to baseline.
6. Record detection time, rollback start, recovery time, affected requests, and
   follow-up owner.

## Database warning

Application rollback does not reverse a database migration. Backward-compatible
schema changes and an explicit migration rollback plan are required before a
release that changes the schema.
