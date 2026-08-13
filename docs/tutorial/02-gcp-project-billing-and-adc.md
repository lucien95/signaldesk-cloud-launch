# 02 — Create the GCP project, enable billing, and set ADC context

## Outcome

You have one intended Google Cloud project with billing enabled, the correct
human account selected, and Application Default Credentials (ADC) configured
to charge client-library quota to that same project.

## Business reason

An isolated client project gives resources, IAM, audit history, quotas, and
cost reporting a clear ownership boundary. Correct local credential context
prevents an engineer from deploying into the wrong client or charging API quota
to an unrelated project.

## Concepts

- **Project name** is a human label and can be changed.
- **Project ID** is globally unique and is used by commands, APIs, and resource
  names.
- **Project number** is Google's numeric identifier and is sometimes used by
  service agents; it is not the same as a GitHub repository ID.
- **Billing account** pays for eligible project usage. Linking it enables paid
  services; it does not create workloads.
- **gcloud account** is the human identity used by CLI commands.
- **ADC** is the credential lookup used by Terraform and Google client
  libraries.
- **ADC quota project** tells client libraries which project should receive
  quota and certain API charges. It is a setting inside the credential file,
  not another isolated project, network, or billing account.

## Before you run anything

For the reference deployment:

```bash
export PROJECT_ID="kloudwithlucien-503200"
export REGION="us-east1"
export OWNER_ACCOUNT="your-gcp-owner@example.com"
```

A reader reproducing the lab must replace `PROJECT_ID` and `OWNER_ACCOUNT` with
their own values and use their own billing-enabled Google account. Never copy
the reference billing-account ID.

## Implementation

### 1. Create and link the project in the console

1. Open Google Cloud Console and use the project selector.
2. Choose **New project**, set a recognizable project name, and choose or
   create the appropriate organization/folder if applicable.
3. Record the generated project ID before creating resources.
4. Open **Billing → My projects**, choose **Link a billing account**, and select
   the intended billing account.
5. Return to the project selector and confirm the new project is active.

Creating a new billing account may require legal name, country, payment profile,
and payment method. Those screens are private setup screens and must never be
used as portfolio screenshots.

### 2. Configure the local human context

```bash
gcloud auth login
gcloud config set account "${OWNER_ACCOUNT}"
gcloud config set project "${PROJECT_ID}"
gcloud config set compute/region "${REGION}"
```

Verify it using valid single-purpose commands:

```bash
gcloud auth list --filter=status:ACTIVE --format='value(account)'
gcloud config get-value project
gcloud config get-value compute/region
gcloud billing projects describe "${PROJECT_ID}" \
  --format='value(billingEnabled)'
```

Do not use `gcloud config list account project`; those trailing values are
interpreted as unsupported arguments. `gcloud config get-value` is clearer for
individual properties.

### 3. Create ADC for Terraform

```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project "${PROJECT_ID}"
```

On the Google consent screen, approve the Cloud Platform scope. If the browser
returns only `openid` and email scopes, sign out of the conflicting Google
session or use a private browser window, rerun the command, and consent with the
project-owning account.

Verify context without printing a token:

```bash
printf 'account=%s\n' "$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
printf 'project=%s\n' "$(gcloud config get-value project 2>/dev/null)"
printf 'quota_project=%s\n' "$(jq -r '.quota_project_id' ~/.config/gcloud/application_default_credentials.json)"
printf 'billing_enabled=%s\n' "$(gcloud billing projects describe "${PROJECT_ID}" --format='value(billingEnabled)')"
```

Never display the entire ADC JSON file. It contains a refresh token.

## Expected result

- The active human account is the project owner/operator.
- The configured project and ADC quota project are identical.
- Billing reports `True`.
- No infrastructure exists merely because these settings were added.

## Screenshot checkpoints

- **SD-02-01** — project dashboard header showing the intended project name and
  ID.
- **SD-02-02** — billing enabled status with account/payment details cropped.
- **SD-02-03** — only the four formatted values from the final verification
  block.

Do not capture the authentication URL, device code, OAuth callback, entire ADC
file, billing-account ID, project payment profile, or unrelated accounts.

## Security and cost review

The initial bootstrap uses a human owner because it creates the automation
trust root. Routine deployment must move to federated service accounts after
bootstrap. Billing linkage enables chargeable services, but no cost is incurred
until billable resources/API usage begin. Project-level budgets are configured
later and do not hard-stop consumption.

## Troubleshooting

- `cloud-platform scope is required but not consented`: repeat ADC login in a
  clean browser session with the correct account and approve the requested
  scope.
- `serviceusage.services.use permission`: verify ADC belongs to an account with
  suitable project permission, then rerun `set-quota-project`.
- CLI account and ADC account differ: revoke/recreate ADC under the intended
  operator; changing `gcloud config set account` alone does not rewrite ADC.
- Billing is disabled: stop. Cloud SQL and other services will fail later.

## Explain it in an interview

> I used the GCP project as the workload, IAM, quota, audit, and cost boundary.
> My human gcloud account performs the one-time bootstrap, while Terraform finds
> that credential through ADC. Setting the ADC quota project does not create a
> new project; it attributes eligible client-library quota and billing context
> to the workload project. Automated delivery later replaces the human
> credential with short-lived federated service-account credentials.

## Completion gate

- [ ] I can distinguish project name, ID, number, and billing account.
- [ ] I can explain gcloud user credentials versus ADC.
- [ ] Active account, active project, quota project, and billing status match.
- [ ] No token, OAuth URL/code, ADC JSON, or billing ID is in Git or screenshots.
- [ ] SD-02-01 through SD-02-03 are sanitized and recorded.

[Previous: 01 — Workstation and repository](01-workstation-and-repository.md) · [Next: 03 — Bootstrap the trust root](03-bootstrap-trust-root.md)
