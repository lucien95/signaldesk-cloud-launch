# Deployment prerequisites

## GitHub repository variables

Configure these as repository or protected-environment variables:

- `GCP_PROJECT_ID`
- `GCP_REGION`
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_DEPLOY_SERVICE_ACCOUNT`
- `GCP_ARTIFACT_REPOSITORY`
- `GCP_CLOUD_RUN_SERVICE`

No service-account key is required.

## Initial sequence

1. Authenticate locally with an identity allowed to create the bootstrap
   resources.
2. Apply `terraform/bootstrap` using local state for the first run.
3. Copy the generated backend example into each environment only after the state
   bucket exists, then migrate state.
4. Apply `terraform/environments/dev`.
5. Add the output values to GitHub repository variables.
6. Run the application deployment workflow.
7. Record smoke-test and rollback evidence.

## Important boundary

The bootstrap configuration is privileged. Do not give the application
deployment identity organization, billing, service-account-admin, or project IAM
administration permissions.
