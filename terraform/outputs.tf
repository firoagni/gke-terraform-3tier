output "project" {
  value = "${var.project_id}"
}

output "network" {
  value = "${google_compute_network.vpc_network.name}"
}

output "subnet" {
  value = "${google_compute_subnetwork.subnetwork.name}"
}

output "region" {
  value = "${google_compute_subnetwork.subnetwork.region}"
}

output "k8s_nodes_internal_ip_ranges" {
  value = "${google_compute_subnetwork.subnetwork.ip_cidr_range}"
}

output "k8s_pods_internal_ip_ranges" {
  value = "${google_compute_subnetwork.subnetwork.secondary_ip_range.0.ip_cidr_range}"
}

output "k8s_services_internal_ip_ranges" {
  value = "${google_compute_subnetwork.subnetwork.secondary_ip_range.1.ip_cidr_range}"
}

output "nat_public_ip" {
  value = "${google_compute_address.nat_ip.id}"
}


