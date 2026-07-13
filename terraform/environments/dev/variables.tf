variable "project_id" {
  description = "Existing GCP project ID."
  type        = string
}

variable "region" {
  description = "Primary deployment region."
  type        = string
  default     = "us-east1"
}

variable "environment" {
  description = "Environment name used in resource names and labels."
  type        = string
  default     = "dev"
}

variable "billing_account_id" {
  description = "Optional billing account override; empty derives it from the project."
  type        = string
  default     = ""
}

variable "deploy_service_account_email" {
  description = "GitHub deployer service-account email created by terraform/bootstrap."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget amount; this is an alert, not a hard spending cap."
  type        = number
  default     = 10
}

variable "database_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-f1-micro"
}

variable "database_deletion_protection" {
  description = "Protect the database from accidental Terraform deletion."
  type        = bool
  default     = false
}

variable "cloud_run_max_instances" {
  description = "Maximum Cloud Run instances used as a cost and DB connection guardrail."
  type        = number
  default     = 3
}

variable "allow_unauthenticated" {
  description = "Expose the demonstration booking API publicly."
  type        = bool
  default     = true
}
