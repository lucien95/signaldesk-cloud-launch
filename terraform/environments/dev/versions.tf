terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6, < 4.0"
    }
  }

  # Add the GCS backend only after terraform/bootstrap has created the bucket.
  # backend "gcs" {
  #   bucket = "your-signaldesk-tfstate"
  #   prefix = "signaldesk/dev"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
