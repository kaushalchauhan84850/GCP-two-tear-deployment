terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Remote state per environment. Each environment (dev/qa/prod) uses a
  # different GCS bucket/prefix, passed in via -backend-config at init time.
  # See README for the exact `terraform init` commands.
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
