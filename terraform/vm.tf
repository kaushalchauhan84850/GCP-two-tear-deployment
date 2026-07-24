resource "google_compute_instance" "backend" {
  name         = "${var.environment}-backend-vm"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["backend"]

  boot_disk {
    initialize_params {
      image = var.frontend_image
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
    # No access_config block => no external/public IP (private VM)
  }

  metadata_startup_script = templatefile("${path.module}/startup-backend.sh.tpl", {
    dockerhub_username = var.dockerhub_username
    image_tag           = var.image_tag
    environment          = var.environment
    mongo_uri            = var.mongo_uri
  })

  labels = {
    role        = "backend"
    environment = var.environment
  }
}

resource "google_compute_instance" "frontend" {
  name         = "${var.environment}-frontend-vm"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["frontend"]

  depends_on = [google_compute_instance.backend]

  boot_disk {
    initialize_params {
      image = var.frontend_image
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    access_config {
      # Ephemeral public IP so users can reach the form
    }
  }

  metadata_startup_script = templatefile("${path.module}/startup-frontend.sh.tpl", {
    dockerhub_username = var.dockerhub_username
    image_tag           = var.image_tag
    environment          = var.environment
    backend_private_ip   = google_compute_instance.backend.network_interface[0].network_ip
  })

  labels = {
    role        = "frontend"
    environment = var.environment
  }
}
