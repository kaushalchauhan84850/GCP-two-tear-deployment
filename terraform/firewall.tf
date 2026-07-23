# Allow SSH only via Identity-Aware Proxy (no open 0.0.0.0/0:22)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.environment}-allow-iap-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["frontend", "backend"]
}

# Allow the public internet to hit the frontend VM on port 80
resource "google_compute_firewall" "allow_http_frontend" {
  name    = "${var.environment}-allow-http-frontend"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["frontend"]
}

# Allow the frontend subnet to reach the backend VM on the API port (5000)
resource "google_compute_firewall" "allow_backend_from_frontend" {
  name    = "${var.environment}-allow-backend-from-frontend"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = [google_compute_subnetwork.public_subnet.ip_cidr_range]
  target_tags   = ["backend"]
}

# Allow internal traffic between subnets (health checks, etc.)
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = [
    google_compute_subnetwork.public_subnet.ip_cidr_range,
    google_compute_subnetwork.private_subnet.ip_cidr_range
  ]
}
