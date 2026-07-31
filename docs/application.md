# SignalDesk application guide

SignalDesk is an end-to-end field-service booking proof asset. It is designed
to make the infrastructure observable from the product: every booking passes
through the public Cloud Run URL, FastAPI validation, the private database
path, and request-correlated logging.

## User journeys

### Customer booking

1. The browser loads the statically exported Next.js interface from FastAPI.
2. The interface reads the service catalog and the selected day's live
   availability from `/api/v1`.
3. The customer supplies a name, email, service, date, and available arrival
   window. The UI prevents incomplete submissions, but the API repeats every
   important validation because browsers are not trust boundaries.
4. FastAPI accepts only supported services, timezone-aware future appointments,
   weekdays, and the five configured Eastern-time windows.
5. SQLAlchemy writes the booking to PostgreSQL in Cloud SQL. A duplicate active
   appointment returns `409 Conflict` instead of silently double-booking.
6. The confirmation shows the booking reference, normalized appointment time,
   status, and request ID used to find the matching structured log entry.

### Operations workflow

1. The board requests bookings with optional status and text filters.
2. Summary cards calculate confirmed, completed, and cancelled counts from the
   current view.
3. An operator confirms before completing or cancelling a booking.
4. The API persists the terminal status and prevents that booking from being
   reopened. The UI displays the new status and the update request ID.

The operations board is intentionally a **public synthetic-data lab**. The UI
states this boundary. Real customer deployment requires staff authentication
and role-based authorization on the list, search, and update endpoints.

## Runtime connection

```text
Browser
  -> Cloud Run public HTTPS URL
     -> Next.js static interface at /
     -> FastAPI routes at /api/v1
        -> SQLAlchemy/psycopg
           -> Cloud SQL private Unix socket
              -> PostgreSQL user + Secret Manager password
```

The Cloud Run service account grants the workload permission to access the
Cloud SQL instance and secret. PostgreSQL still performs database-level
authentication with the username and injected password. IAM opens the secure
route to the resource; it does not become the database user in this release.

## Source map

| Location | Responsibility | Change it when |
|---|---|---|
| `app/frontend/app/page.tsx` | Customer and operations workflows and UI state | A user journey or product rule changes |
| `app/frontend/app/globals.css` | Responsive visual system and interaction states | Layout, accessibility, or branding changes |
| `app/frontend/lib/api.ts` | Same-origin API client and request IDs | An endpoint or response contract changes |
| `app/signaldesk/main.py` | HTTP routes, persistence orchestration, logging | API behavior changes |
| `app/signaldesk/schemas.py` | Untrusted input and response validation | A booking rule or API model changes |
| `app/signaldesk/services.py` | Service catalog and business schedule | Pricing, duration, or appointment windows change |
| `app/Dockerfile` | Reproducible frontend build and final runtime image | Runtime or build dependencies change |
| `.github/workflows/ci.yml` | Unit, browser, build, and dependency gates | The required evidence changes |

## Local verification

Run the entire packaged application:

```bash
cp .env.example .env
docker compose up --build
```

Open `http://localhost:8080`, submit a synthetic booking, open the operations
board, search for the customer, and mark the booking complete. Then verify the
same journey automatically:

```bash
make install
make frontend-e2e
```

The browser suite runs the compiled frontend and FastAPI together against a
disposable in-memory database in desktop Chrome and a Pixel 7 viewport. The
backend suite separately covers invalid input, duplicate-slot conflicts,
filtering, cancellation, and terminal status rules.

## Production extension checklist

- Protect operations routes with a real identity provider and staff roles.
- Add rate limits and abuse protection before accepting public traffic at
  business scale.
- Add email/SMS confirmations through an asynchronous queue and idempotent
  worker.
- Add schema migrations instead of startup table creation.
- Add custom domain, Cloud Armor, and an explicit privacy/retention policy.
- Promote Cloud SQL to HA when the recovery objective justifies the cost.
