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

variable "state_bucket_name" {
  description = "Globally unique bucket name for Terraform state."
  type        = string
}
