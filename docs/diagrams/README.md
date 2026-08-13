# Architecture diagram sources

## Files

- `signaldesk-runtime-architecture.svg` — public request, runtime identity,
  secret injection, Direct VPC egress, private Cloud SQL, observability, and
  cost controls.
- `signaldesk-delivery-architecture.svg` — bootstrap trust root, pull-request
  gates, OIDC federation, exact-plan approval, immutable application release,
  candidate verification, and promotion.
- `signaldesk-architecture.drawio` — editable two-page source for both views.

## Open in Lucidchart

Lucidchart supports importing Draw.io documents. From the Lucid documents page:

1. Select **+ New**.
2. Select **Import documents**.
3. Choose **Draw.io**.
4. Upload `signaldesk-architecture.drawio`.
5. Confirm both pages imported: **01 Runtime Architecture** and
   **02 CI-CD and Trust**.
6. Keep the SVG files as the reviewed publication exports.

## Diagram conventions

- large containers are trust, project, region, or network boundaries;
- solid dark arrows are runtime requests and private data paths;
- blue arrows are infrastructure identity and plan flows;
- violet arrows are application identity and release flows;
- dashed arrows are control-plane references, not application traffic;
- Cloud Run and Cloud SQL sit outside the dashed VPC enclosure because they are
  managed services; the VPC represents their private connectivity path;
- arrows are numbered so the manual verification lab can connect each visual
  claim to command evidence;
- public exposure, development-only tradeoffs, and pending reliability drills
  remain explicit instead of being hidden for presentation.

## Source policy

The publication SVGs use the 2025 Google Cloud core product icon geometry for
Cloud Run, Cloud SQL, and Cloud Storage. The official icon library is available
at <https://cloud.google.com/icons>. Keep service names beside icons so the
diagram remains understandable without relying on color or icon recognition.
