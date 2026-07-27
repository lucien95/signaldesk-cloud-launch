locals {
  delivery_workflow_ref    = "${var.github_repository}/${var.github_delivery_workflow}@refs/heads/${var.github_default_branch}"
  application_workflow_ref = "${var.github_repository}/${var.github_application_workflow}@refs/heads/${var.github_default_branch}"
}

resource "google_project_service" "bootstrap" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "terraform_state" {
  # checkov:skip=CKV_GCP_62:Storage Data Access audit logs are enabled below; a second access-log bucket would add recursive logging and cost for this isolated lab project.
  name                        = var.state_bucket_name
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age            = 1
      matches_prefix = ["plans/"]
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.bootstrap]
}

resource "google_project_iam_audit_config" "storage_data_access" {
  project = var.project_id
  service = "storage.googleapis.com"

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_service_account" "application_deployer" {
  project      = var.project_id
  account_id   = "signaldesk-github-deploy"
  display_name = "SignalDesk GitHub application deployer"

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.bootstrap]
}

resource "google_service_account" "infrastructure_deployer" {
  project      = var.project_id
  account_id   = "signaldesk-terraform-deploy"
  display_name = "SignalDesk GitHub infrastructure deployer"

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool" "application" {
  project                   = var.project_id
  workload_identity_pool_id = "signaldesk-app"
  display_name              = "SignalDesk application delivery"
  description               = "Keyless GitHub Actions authentication for application releases"

  lifecycle {
    prevent_destroy = true
  }
  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool" "infrastructure" {
  project                   = var.project_id
  workload_identity_pool_id = "signaldesk-infra"
  display_name              = "SignalDesk infra delivery"
  description               = "Keyless GitHub Actions authentication for Terraform delivery"

  lifecycle {
    prevent_destroy = true
  }
  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool_provider" "application" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.application.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub application delivery"

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.environment"         = "assertion.environment"
    "attribute.job_workflow_ref"    = "assertion.job_workflow_ref"
    "attribute.ref"                 = "assertion.ref"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
  }

  attribute_condition = join(" && ", [
    "assertion.repository_id == '${var.github_repository_id}'",
    "assertion.repository_owner_id == '${var.github_repository_owner_id}'",
    "assertion.ref == 'refs/heads/${var.github_default_branch}'",
    "assertion.workflow_ref == '${local.delivery_workflow_ref}'",
    "assertion.job_workflow_ref == '${local.application_workflow_ref}'",
    "assertion.environment == 'development'",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com/"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_iam_workload_identity_pool_provider" "infrastructure" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.infrastructure.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub infrastructure delivery"

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.environment"         = "assertion.environment"
    "attribute.ref"                 = "assertion.ref"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
  }

  attribute_condition = join(" && ", [
    "assertion.repository_id == '${var.github_repository_id}'",
    "assertion.repository_owner_id == '${var.github_repository_owner_id}'",
    "assertion.ref == 'refs/heads/${var.github_default_branch}'",
    "assertion.workflow_ref == '${local.delivery_workflow_ref}'",
    "assertion.environment in ['infrastructure-plan', 'infrastructure-development']",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com/"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_service_account_iam_member" "application_impersonation" {
  service_account_id = google_service_account.application_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.application.name}/attribute.repository_id/${var.github_repository_id}"
}

resource "google_service_account_iam_member" "infrastructure_impersonation" {
  service_account_id = google_service_account.infrastructure_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.infrastructure.name}/attribute.repository_id/${var.github_repository_id}"
}

resource "google_project_iam_member" "application_deploy_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/run.developer",
  ])

  project = var.project_id
  role    = each.value
  member  = google_service_account.application_deployer.member
}

resource "google_project_iam_member" "infrastructure_deploy_roles" {
  for_each = toset([
    "roles/artifactregistry.admin",
    "roles/cloudsql.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/monitoring.editor",
    "roles/resourcemanager.projectIamAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
    "roles/servicenetworking.networksAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ])

  project = var.project_id
  role    = each.value
  member  = google_service_account.infrastructure_deployer.member
}

resource "google_project_iam_member" "infrastructure_service_account_admin" {
  # checkov:skip=CKV_GCP_49:The isolated Terraform identity must create the runtime service account and manage its narrow actAs bindings; OIDC conditions and an approval environment protect this privilege.
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = google_service_account.infrastructure_deployer.member
}

resource "google_storage_bucket_iam_member" "infrastructure_state" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.infrastructure_deployer.member
}

resource "google_billing_account_iam_member" "infrastructure_budget" {
  billing_account_id = var.billing_account_id
  role               = "roles/billing.costsManager"
  member             = google_service_account.infrastructure_deployer.member
}
