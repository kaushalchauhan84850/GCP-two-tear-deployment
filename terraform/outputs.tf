output "frontend_public_ip" {
  description = "Public IP of the frontend VM - open this in a browser"
  value       = google_compute_instance.frontend.network_interface[0].access_config[0].nat_ip
}

output "backend_private_ip" {
  description = "Internal IP of the backend VM"
  value       = google_compute_instance.backend.network_interface[0].network_ip
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}
