output "cloud_run_service" {
  value = google_cloud_run_v2_service.api.name
}

output "cloud_run_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "artifact_repository" {
  value = google_artifact_registry_repository.app.repository_id
}

output "database_instance" {
  value = google_sql_database_instance.postgres.name
}

output "runtime_service_account" {
  value = google_service_account.runtime.email
}
