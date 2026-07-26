variable "project_id" {
  description = "Existing GCP project used by the development environment."
  type        = string
}

variable "region" {
  description = "Primary deployment region."
  type        = string
  default     = "us-east1"
}

variable "github_repository" {
  description = "GitHub repository in owner/name form."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID used in OIDC trust conditions."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must contain only digits."
  }
}

variable "github_repository_owner_id" {
  description = "Immutable numeric GitHub owner ID used in OIDC trust conditions."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_owner_id))
    error_message = "github_repository_owner_id must contain only digits."
  }
}

variable "github_default_branch" {
  description = "Only this branch may obtain deployment credentials."
  type        = string
  default     = "main"
}

variable "github_delivery_workflow" {
  description = "Repository-relative path to the trusted delivery orchestrator."
  type        = string
  default     = ".github/workflows/delivery.yml"
}

variable "github_application_workflow" {
  description = "Repository-relative path to the trusted reusable application workflow."
  type        = string
  default     = ".github/workflows/deploy.yml"
}

variable "billing_account_id" {
  description = "Billing account ID used to grant the infrastructure identity budget-management access."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique bucket name for Terraform state."
  type        = string
}
