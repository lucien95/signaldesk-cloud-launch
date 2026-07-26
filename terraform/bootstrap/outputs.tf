output "state_bucket" {
  value = google_storage_bucket.terraform_state.name
}

output "application_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.application.name
}

output "infrastructure_workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.infrastructure.name
}

output "application_deploy_service_account" {
  value = google_service_account.application_deployer.email
}

output "infrastructure_deploy_service_account" {
  value = google_service_account.infrastructure_deployer.email
}
