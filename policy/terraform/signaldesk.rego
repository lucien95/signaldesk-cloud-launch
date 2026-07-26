package signalops.terraform

import rego.v1

protected_resource_types := {
	"google_iam_workload_identity_pool",
	"google_iam_workload_identity_pool_provider",
	"google_sql_database_instance",
	"google_storage_bucket",
}

labelled_resource_types := {
	"google_artifact_registry_repository",
	"google_cloud_run_v2_service",
	"google_secret_manager_secret",
	"google_sql_database_instance",
}

required_labels := {"application", "environment", "managed_by", "owner"}

deny contains message if {
	some resource in input.resource_changes
	resource.type in protected_resource_types
	"delete" in resource.change.actions
	message := sprintf("Protected resource %s (%s) cannot be deleted by the standard pipeline", [resource.address, resource.type])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type in labelled_resource_types
	resource.change.after != null
	labels := resource_labels(resource)
	missing := required_labels - {label | some label in object.keys(labels)}
	count(missing) > 0
	message := sprintf("%s is missing required labels: %v", [resource.address, sort(missing)])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_storage_bucket"
	resource.change.after != null
	not object.get(resource.change.after, "uniform_bucket_level_access", false)
	message := sprintf("%s must enable uniform bucket-level access", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_storage_bucket"
	resource.change.after != null
	object.get(resource.change.after, "public_access_prevention", "") != "enforced"
	message := sprintf("%s must enforce public access prevention", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_storage_bucket"
	resource.change.after != null
	versioning := object.get(resource.change.after, "versioning", [])
	not versioning_enabled(versioning)
	message := sprintf("%s must enable object versioning", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_cloud_run_v2_service"
	resource.change.after != null
	template := object.get(resource.change.after, "template", [])[0]
	object.get(template, "service_account", "") == ""
	message := sprintf("%s must use a dedicated runtime service account", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_cloud_run_v2_service"
	resource.change.after != null
	template := object.get(resource.change.after, "template", [])[0]
	scaling := object.get(template, "scaling", [])[0]
	object.get(scaling, "max_instance_count", 0) > 3
	message := sprintf("%s exceeds the development cost guardrail of three instances", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_cloud_run_v2_service_iam_member"
	resource.change.after != null
	object.get(resource.change.after, "member", "") == "allUsers"
	object.get(resource.change.after, "name", "") != "signaldesk-dev"
	message := sprintf("%s exposes a non-development Cloud Run service publicly", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	resource.change.after != null
	settings := object.get(resource.change.after, "settings", [])[0]
	backups := object.get(settings, "backup_configuration", [])[0]
	not object.get(backups, "enabled", false)
	message := sprintf("%s must enable automated backups", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	resource.change.after != null
	settings := object.get(resource.change.after, "settings", [])[0]
	backups := object.get(settings, "backup_configuration", [])[0]
	not object.get(backups, "point_in_time_recovery_enabled", false)
	message := sprintf("%s must enable point-in-time recovery", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	resource.change.after != null
	settings := object.get(resource.change.after, "settings", [])[0]
	ip_configuration := object.get(settings, "ip_configuration", [])[0]
	object.get(ip_configuration, "ssl_mode", "") != "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
	message := sprintf("%s must require encrypted database connections with trusted client certificates", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	resource.change.after != null
	settings := object.get(resource.change.after, "settings", [])[0]
	ip_configuration := object.get(settings, "ip_configuration", [])[0]
	object.get(ip_configuration, "ipv4_enabled", true)
	message := sprintf("%s must not expose a public IPv4 database address", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	resource.change.after != null
	settings := object.get(resource.change.after, "settings", [])[0]
	ip_configuration := object.get(settings, "ip_configuration", [])[0]
	object.get(ip_configuration, "private_network", "") == ""
	message := sprintf("%s must attach to a private VPC network", [resource.address])
}

deny contains message if {
	some resource in input.resource_changes
	resource.type == "google_sql_database_instance"
	resource.change.after != null
	object.get(resource.change.after, "deletion_protection", false) == false
	settings := object.get(resource.change.after, "settings", [])[0]
	labels := object.get(settings, "user_labels", {})
	object.get(labels, "environment", "") == "prod"
	message := sprintf("%s must enable deletion protection in production", [resource.address])
}

versioning_enabled(versioning) if {
	count(versioning) > 0
	object.get(versioning[0], "enabled", false)
}

resource_labels(resource) := labels if {
	resource.type == "google_sql_database_instance"
	settings := object.get(resource.change.after, "settings", [])[0]
	labels := object.get(settings, "user_labels", {})
}

resource_labels(resource) := labels if {
	resource.type != "google_sql_database_instance"
	labels := object.get(resource.change.after, "labels", {})
}
