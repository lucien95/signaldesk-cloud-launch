# cloudwithlucien.com portfolio entry

## Display copy

### Title

SignalDesk Cloud Launch

### Subtitle

Keyless, policy-gated booking platform on Google Cloud

### Short description

A deployed Next.js and FastAPI booking application on Cloud Run with private
PostgreSQL, Terraform-managed infrastructure, keyless GitHub Actions delivery,
DevSecOps policy gates, request-correlated logging, and cost guardrails.

### Case-study introduction

SignalDesk is a production-style reference implementation for a small service
business that needs online appointment booking without operating servers or
Kubernetes. Customers reserve live service windows, and an operations board
retrieves and updates the resulting PostgreSQL records.

The proof asset focuses on integration: GitHub-to-GCP OIDC trust, separated
deployment/runtime/database identities, Direct VPC egress to private Cloud SQL,
Secret Manager injection, exact-plan Terraform approval, zero-traffic Cloud Run
promotion, structured request correlation, and bounded serverless cost.

### Verified highlights

- Full-stack Cloud Run revision deployed by immutable image digest.
- 100% traffic only after candidate readiness, API, and UI checks passed.
- Private-IP Cloud SQL; public IP connectivity disabled.
- Zero user-managed keys on both CI service accounts.
- Six successful pull-request jobs across application, Terraform, and security.
- Checkov, custom OPA, Trivy, dependency audit, and CycloneDX SBOM controls.
- Cloud Run minimum zero and maximum three instances.
- Monthly USD 10 budget alerts at 50%, 90%, and 100%.
- Booking request correlated from browser confirmation to structured Cloud Log.

### Business value

- Replaces manual cloud changes with reviewed infrastructure as code.
- Reduces credential risk by removing permanent CI service-account keys.
- Limits failed-release exposure with zero-traffic candidate testing.
- Reduces database exposure through private networking and layered identity.
- Gives a lean team operational evidence without adopting Kubernetes.
- Places explicit bounds around serverless scale and budget notifications.

### Honest limitations

This is a synthetic-data development reference. Before real customer use, add
staff authentication and RBAC, rate limiting, managed edge protection, schema
migrations, notification workers, a data-retention policy, HA based on recovery
objectives, and completed restore/load/alert drills.

## Portfolio API field map

```json
{
  "title": "SignalDesk Cloud Launch",
  "slug": "signaldesk-cloud-launch",
  "shortDescription": "Keyless, policy-gated GCP booking platform with private PostgreSQL and verified Cloud Run promotion.",
  "description": "A deployed Next.js and FastAPI booking application on Cloud Run with private Cloud SQL, Terraform-managed infrastructure, keyless GitHub Actions, DevSecOps gates, structured logging, and cost guardrails.",
  "category": "infrastructure",
  "status": "completed",
  "client": "Portfolio reference implementation",
  "duration": "1 week",
  "role": "Cloud and Platform Engineer",
  "teamSize": 1,
  "industry": "Field services",
  "complexity": "advanced",
  "technologies": [
    "Google Cloud Run",
    "Cloud SQL for PostgreSQL",
    "Terraform",
    "FastAPI",
    "Next.js",
    "React",
    "Docker",
    "GitHub Actions"
  ],
  "cloudProviders": ["Google Cloud"],
  "tools": [
    "Workload Identity Federation",
    "Secret Manager",
    "Artifact Registry",
    "Cloud Logging",
    "Cloud Monitoring",
    "Checkov",
    "OPA",
    "Trivy",
    "Playwright",
    "CycloneDX"
  ],
  "infrastructure": {
    "containers": 1,
    "services": [
      "Cloud Run",
      "Cloud SQL",
      "Artifact Registry",
      "Secret Manager",
      "VPC",
      "Cloud Logging",
      "Cloud Monitoring",
      "Cloud Billing Budget"
    ],
    "architecture": "Single-origin Next.js and FastAPI container on Cloud Run with Direct VPC egress to private Cloud SQL"
  },
  "metrics": {
    "customMetrics": [
      {"label": "User-managed CI keys", "value": "0"},
      {"label": "Cloud Run minimum instances", "value": "0"},
      {"label": "Cloud Run maximum instances", "value": "3"},
      {"label": "Public database IPs", "value": "0"},
      {"label": "Monthly budget alert", "value": "$10"},
      {"label": "Verified revision traffic", "value": "100%"}
    ]
  },
  "keyFeatures": [
    "Private PostgreSQL data path using Direct VPC egress and Private Service Access",
    "Keyless GitHub Actions authentication with separate application and infrastructure identities",
    "Exact-plan Terraform approval with OPA evaluation and SHA-256 verification",
    "Container scanning and CycloneDX SBOM evidence",
    "Zero-traffic Cloud Run candidate smoke testing and immutable digest promotion",
    "Request IDs correlated from booking confirmation to structured Cloud Logging",
    "Scale-to-zero runtime with an explicit three-instance ceiling and budget alerts"
  ],
  "challenges": [
    "Replaced a scanner-blocked public database path with private networking",
    "Resolved Cloud SQL edition and tier compatibility",
    "Adjusted Cloud Run probes to supported runtime behavior",
    "Updated OPA policy logic to match real Terraform plan normalization",
    "Fixed candidate lookup while the existing revision retained production traffic",
    "Separated Terraform platform ownership from application revision ownership"
  ],
  "results": [
    "Deployed a manually testable full-stack booking workflow",
    "Verified private database persistence and terminal status updates",
    "Released without permanent Google Cloud credentials in GitHub",
    "Applied policy-checked infrastructure through a tamper-evident plan",
    "Promoted the application only after candidate validation",
    "Correlated a customer-visible request ID to the exact backend log"
  ],
  "links": {
    "github": "https://github.com/lucien95/signaldesk-cloud-launch",
    "documentation": "https://github.com/lucien95/signaldesk-cloud-launch/blob/main/docs/portfolio-writeup.md",
    "live": "https://signaldesk-dev-s2wvuscfya-ue.a.run.app",
    "casestudy": "[MEDIUM_OR_SUBSTACK_URL]"
  },
  "images": {
    "thumbnail": "00-live-application-overview.png",
    "architecture": ["architecture-overview.png"],
    "screenshots": [
      "03-booking-confirmation.png",
      "09-cloud-sql-private-network.png",
      "12-main-delivery.png",
      "13-candidate-promotion.png",
      "15b-structured-request-log.png"
    ]
  },
  "featured": true,
  "order": 1,
  "tags": [
    "GCP",
    "Cloud Run",
    "Cloud SQL",
    "Terraform",
    "GitHub Actions",
    "DevSecOps",
    "Platform Engineering"
  ]
}
```

## Primary calls to action

- **View live demonstration** → Cloud Run URL.
- **Read the technical walkthrough** → Medium or Substack.
- **Inspect the source and evidence** → GitHub repository.
- **Discuss a cloud foundation** → SignalOps consultation page.
