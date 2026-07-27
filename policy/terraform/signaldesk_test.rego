package signalops.terraform_test

import data.signalops.terraform
import rego.v1

test_secure_bucket_allowed if {
	count(terraform.deny) == 0 with input as plan([
		change("google_storage_bucket.terraform_state", "google_storage_bucket", ["create"], {
			"uniform_bucket_level_access": true,
			"public_access_prevention": "enforced",
			"versioning": [{"enabled": true}],
		}),
	])
}

test_protected_database_delete_denied if {
	violations := terraform.deny with input as plan([
		change("google_sql_database_instance.postgres", "google_sql_database_instance", ["delete"], null),
	])
	count(violations) == 1
}

test_insecure_bucket_denied if {
	violations := terraform.deny with input as plan([
		change("google_storage_bucket.terraform_state", "google_storage_bucket", ["create"], {
			"uniform_bucket_level_access": false,
			"public_access_prevention": "inherited",
			"versioning": [{"enabled": false}],
		}),
	])
	count(violations) == 3
}

test_cloud_run_cost_limit_denied if {
	violations := terraform.deny with input as plan([
		change("google_cloud_run_v2_service.api", "google_cloud_run_v2_service", ["create"], {
			"labels": {
				"application": "signaldesk",
				"environment": "dev",
				"managed_by": "terraform",
				"owner": "signalops",
			},
			"template": [{
				"service_account": "runtime@example.iam.gserviceaccount.com",
				"scaling": [{"max_instance_count": 20}],
			}],
		}),
	])
	count(violations) == 1
}

test_public_production_service_denied if {
	violations := terraform.deny with input as plan([
		change("google_cloud_run_v2_service_iam_member.public", "google_cloud_run_v2_service_iam_member", ["create"], {
			"member": "allUsers",
			"name": "signaldesk-prod",
		}),
	])
	count(violations) == 1
}

test_database_resilience_controls_denied if {
	violations := terraform.deny with input as plan([
		change("google_sql_database_instance.postgres", "google_sql_database_instance", ["create"], {
			"deletion_protection": false,
			"settings": [{
				"backup_configuration": [{
					"enabled": false,
					"point_in_time_recovery_enabled": false,
				}],
				"ip_configuration": [{
					"ipv4_enabled": false,
					"private_network": "projects/example/global/networks/signaldesk-prod",
					"ssl_mode": "ALLOW_UNENCRYPTED_AND_ENCRYPTED",
				}],
				"user_labels": {
					"application": "signaldesk",
					"environment": "prod",
					"managed_by": "terraform",
					"owner": "signalops",
				},
			}],
		}),
	])
	count(violations) == 4
}

test_enterprise_plus_shared_core_database_denied if {
	violations := terraform.deny with input as plan([
		change("google_sql_database_instance.postgres", "google_sql_database_instance", ["create"], {
			"deletion_protection": false,
			"settings": [{
				"tier": "db-f1-micro",
				"edition": "ENTERPRISE_PLUS",
				"backup_configuration": [{
					"enabled": true,
					"point_in_time_recovery_enabled": true,
				}],
				"ip_configuration": [{
					"ipv4_enabled": false,
					"private_network": "projects/example/global/networks/signaldesk-dev",
					"ssl_mode": "TRUSTED_CLIENT_CERTIFICATE_REQUIRED",
				}],
				"user_labels": {
					"application": "signaldesk",
					"environment": "dev",
					"managed_by": "terraform",
					"owner": "signalops",
				},
			}],
		}),
	])
	violations == {"google_sql_database_instance.postgres uses Enterprise-only database tier db-f1-micro and must explicitly set edition to ENTERPRISE"}
}

test_public_database_network_denied if {
	violations := terraform.deny with input as plan([
		change("google_sql_database_instance.postgres", "google_sql_database_instance", ["create"], {
			"deletion_protection": true,
			"settings": [{
				"backup_configuration": [{
					"enabled": true,
					"point_in_time_recovery_enabled": true,
				}],
				"ip_configuration": [{
					"ipv4_enabled": true,
					"ssl_mode": "TRUSTED_CLIENT_CERTIFICATE_REQUIRED",
				}],
				"user_labels": {
					"application": "signaldesk",
					"environment": "prod",
					"managed_by": "terraform",
					"owner": "signalops",
				},
			}],
		}),
	])
	count(violations) == 2
}

plan(resource_changes) := {"resource_changes": resource_changes}

change(address, resource_type, actions, after) := {
	"address": address,
	"type": resource_type,
	"change": {
		"actions": actions,
		"after": after,
	},
}
