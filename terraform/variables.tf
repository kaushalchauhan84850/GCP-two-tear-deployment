variable "project_id" {
  description = "GCP project ID (dev-infra-503304 / qa-infra-500307 / prod-infra-503304)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "asia-south1-a"
}

variable "environment" {
  description = "Environment name: dev, qa, or prod"
  type        = string
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-small"
}

variable "frontend_image" {
  description = "Boot image for VMs"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "dockerhub_username" {
  description = "Docker Hub username used to pull images"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy (e.g. dev, qa, prod, git sha)"
  type        = string
  default     = "latest"
}

variable "ssh_source_ranges" {
  description = "CIDR ranges allowed for IAP-based SSH"
  type        = list(string)
  default     = ["35.235.240.0/20"]
}
