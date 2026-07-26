locals {
  name = "signaldesk-${var.environment}"

  budget_billing_account = var.billing_account_id != "" ? var.billing_account_id : data.google_project.current.billing_account

  labels = {
    application = "signaldesk"
    environment = var.environment
    managed_by  = "terraform"
    owner       = "signalops"
  }

  required_services = toset([
    "artifactregistry.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "compute.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_services

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "app" {
  # checkov:skip=CKV_GCP_84:Google-managed encryption is proportionate for the cost-capped development environment; production would use a separately governed CMEK.
  project       = var.project_id
  location      = var.region
  repository_id = "signaldesk"
  description   = "SignalDesk application images"
  format        = "DOCKER"
  labels        = local.labels

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${local.name}-runtime"
  display_name = "SignalDesk ${var.environment} runtime"
}

resource "google_project_iam_member" "runtime_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/secretmanager.secretAccessor",
  ])

  project = var.project_id
  role    = each.value
  member  = google_service_account.runtime.member
}

resource "google_compute_network" "application" {
  project                 = var.project_id
  name                    = local.name
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "application" {
  project                  = var.project_id
  name                     = local.name
  region                   = var.region
  network                  = google_compute_network.application.id
  ip_cidr_range            = "10.10.0.0/24"
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork_iam_member" "application_deployer_network_user" {
  project    = var.project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.application.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${var.deploy_service_account_email}"
}

resource "google_compute_global_address" "private_service_access" {
  project       = var.project_id
  name          = "${local.name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.application.id
}

resource "google_compute_firewall" "deny_unsolicited_ingress" {
  project   = var.project_id
  name      = "${local.name}-deny-ingress"
  network   = google_compute_network.application.name
  direction = "INGRESS"
  priority  = 65534

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_service_networking_connection" "private_service_access" {
  network                 = google_compute_network.application.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
}

resource "google_service_account_iam_member" "deployer_can_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.deploy_service_account_email}"
}

resource "google_service_account_iam_member" "terraform_can_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_service_account_email}"
}

resource "random_password" "database" {
  length           = 32
  special          = true
  override_special = "!#$%&*+-=?@_"
}

resource "google_sql_database_instance" "postgres" {
  project             = var.project_id
  name                = local.name
  region              = var.region
  database_version    = "POSTGRES_18"
  deletion_protection = var.database_deletion_protection

  settings {
    tier                  = var.database_tier
    availability_type     = "ZONAL"
    disk_type             = "PD_SSD"
    disk_size             = 10
    disk_autoresize       = true
    disk_autoresize_limit = 25

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "05:00"
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_duration"
      value = "on"
    }

    database_flags {
      name  = "log_hostname"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_min_error_statement"
      value = "error"
    }

    database_flags {
      name  = "log_statement"
      value = "ddl"
    }

    database_flags {
      name  = "pgaudit.log"
      value = "ddl,role"
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.application.id
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = true
      record_client_address   = false
    }

    user_labels = local.labels
  }

  depends_on = [
    google_project_service.required,
    google_service_networking_connection.private_service_access,
  ]
}

resource "google_sql_database" "app" {
  project  = var.project_id
  name     = "signaldesk"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "app" {
  project  = var.project_id
  name     = "signaldesk_app"
  instance = google_sql_database_instance.postgres.name
  password = random_password.database.result
}

resource "google_secret_manager_secret" "database_password" {
  project   = var.project_id
  secret_id = "${local.name}-database-password"
  labels    = local.labels

  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "database_password" {
  secret      = google_secret_manager_secret.database_password.id
  secret_data = random_password.database.result
}

resource "google_cloud_run_v2_service" "api" {
  project  = var.project_id
  name     = local.name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"
  labels   = local.labels

  deletion_protection = false

  template {
    service_account = google_service_account.runtime.email
    timeout         = "30s"

    vpc_access {
      egress = "PRIVATE_RANGES_ONLY"

      network_interfaces {
        network    = google_compute_network.application.name
        subnetwork = google_compute_subnetwork.application.name
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = var.cloud_run_max_instances
    }

    containers {
      # The application deployment workflow owns this field after bootstrap.
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle = true
      }

      env {
        name  = "APP_ENV"
        value = var.environment
      }

      env {
        name  = "DB_USER"
        value = google_sql_user.app.name
      }

      env {
        name  = "DB_NAME"
        value = google_sql_database.app.name
      }

      env {
        name  = "INSTANCE_CONNECTION_NAME"
        value = google_sql_database_instance.postgres.connection_name
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_password.secret_id
            version = "latest"
          }
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 3
        period_seconds        = 5
        failure_threshold     = 12

        tcp_socket {
          port = 8080
        }
      }

      liveness_probe {
        initial_delay_seconds = 10
        timeout_seconds       = 3
        period_seconds        = 10
        failure_threshold     = 3

        tcp_socket {
          port = 8080
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }

  depends_on = [
    google_compute_subnetwork.application,
    google_service_account_iam_member.terraform_can_act_as_runtime,
    google_project_iam_member.runtime_roles,
    google_secret_manager_secret_version.database_password,
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = google_cloud_run_v2_service.api.project
  location = google_cloud_run_v2_service.api.location
  name     = google_cloud_run_v2_service.api.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_monitoring_uptime_check_config" "ready" {
  project      = var.project_id
  display_name = "${local.name} readiness"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/health/ready"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      host       = trimprefix(google_cloud_run_v2_service.api.uri, "https://")
      project_id = var.project_id
    }
  }
}

resource "google_billing_budget" "monthly" {
  billing_account = local.budget_billing_account
  display_name    = "SignalDesk ${var.environment} monthly budget"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  dynamic "threshold_rules" {
    for_each = toset([0.5, 0.9, 1.0])
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  depends_on = [google_project_service.required]
}

data "google_project" "current" {
  project_id = var.project_id
}
