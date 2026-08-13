# Screenshot standards

The screenshot collection must help another engineer reproduce the build and
help a reviewer verify the claims. More screenshots do not automatically create
better documentation. Capture the smallest frame that proves the step.

## Naming

Use the ID and filename in `screenshot-manifest.yml`:

```text
sd-<chapter>-<sequence>-<short-description>.png
```

Examples:

```text
sd-03-01-bootstrap-plan-summary.png
sd-04-03-wif-attribute-condition.png
sd-07-02-correlated-request-log.png
```

Keep the original private capture outside Git. Add only the reviewed, sanitized
copy to `docs/tutorial/assets/<chapter>/`.

## Capture quality

- Use PNG for console and terminal captures.
- Capture at normal display scale; text must be readable without excessive
  zooming.
- Prefer a 16:9 or compact landscape crop.
- Include enough surrounding UI to establish which service or workflow is
  shown.
- Crop unrelated browser tabs, desktop notifications, personal applications,
  and empty space.
- Use the same light or dark theme consistently within a chapter.
- Do not draw arrows over controls when a short numbered caption is clearer.
- Keep terminal commands and their output together when the command is part of
  the proof.

## Mandatory redaction review

Reject or redact any capture containing:

- passwords, tokens, cookies, authorization codes, or credential JSON;
- Secret Manager payloads or Terraform state content;
- billing-account IDs, payment details, invoices, or full billing pages;
- private IP addresses when they are unnecessary to the public claim;
- unrelated email addresses, customer information, or browser profile details;
- local home-directory names when they add no learning value;
- GitHub environment secrets or any hidden value revealed through browser tools;
- raw headers containing authorization or session material.

Project IDs, public service URLs, repository names, workflow names, service
account display names, role names, and synthetic `example.com` data may be shown
when they are intentionally part of the public project.

## Terminal capture rules

- Clear unrelated command history before capture.
- Show the prompt only when it provides useful repository or directory context.
- Never run a secret-retrieval command for the purpose of taking a screenshot.
- Prefer formatted, bounded output instead of full JSON.
- Do not capture raw Terraform state or a full IAM policy dump.
- Use `--format` and `--filter` so the output proves one claim.

## Console capture rules

- Put the intended GCP project in the project selector before capture.
- Include the page heading and resource name.
- Collapse or crop navigation that does not help orientation.
- For IAM, show only the relevant principal and roles.
- For Cloud SQL, show that public IP is disabled without publishing the private
  address.
- For Secret Manager, show metadata, version state, and IAM—not the payload.
- For GitHub variables, reveal names and non-secret identifiers only; redact the
  billing-account value.

## Caption formula

Each published image should have one sentence containing:

1. what is shown;
2. what claim it proves;
3. any limitation that matters.

Example:

> The Cloud SQL Connections view shows public IPv4 disabled and a private
> network attachment, proving the database is not internet-addressable; the
> private address itself is redacted.

## Manifest statuses

- `planned` — checkpoint is defined but no capture exists;
- `captured` — private original exists;
- `sanitized` — public copy passed the redaction review;
- `published` — referenced by a merged documentation page or portfolio page;
- `rejected` — capture contained unsafe or misleading information and must not
  be used.

## Per-image quality gate

Before changing a manifest entry to `sanitized`, confirm:

- [ ] The image supports a named claim.
- [ ] Text remains readable after crop.
- [ ] Project/service context is visible.
- [ ] No secret or credential material appears.
- [ ] Personal and billing details are removed.
- [ ] The caption describes the evidence honestly.
- [ ] The image does not imply completion of an untested control.
- [ ] The filename and folder match the manifest.

