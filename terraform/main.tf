//--------------------------------------------------------------
// Prerequisite 
//--------------------------------------------------------------

// Any action that Terraform performs require the required API service(s) be enabled first.
resource "google_project_service" "required_api_service" {
  for_each  = toset([
                "cloudresourcemanager.googleapis.com",
                "servicenetworking.googleapis.com",
                "container.googleapis.com",
                "compute.googleapis.com",
                "iam.googleapis.com",
                "logging.googleapis.com",
                "monitoring.googleapis.com",
                "sqladmin.googleapis.com",
                "securetoken.googleapis.com",
                "cloudbilling.googleapis.com",
                "iap.googleapis.com"
            ])
  
  project   = var.project_id
  service   = each.key

  // Do not disable the service on destroy, 
  // as we need the APIs available to destroy the
  // underlying resources.
  disable_on_destroy = false
}

//--------------------------------------------------------------
// Create the VPC and the Subnet that will host the GKE cluster
//--------------------------------------------------------------

//------------------------------------------------------------
// VPCs are global resources in GCP
// -- No manual peering needed between regions, as routing traffic between regions is automatic.
//
// There is no VPC level CIDR block range in GCP. The only level where the CIDR range is defined is in a subnet.
//
// Subnets are regional resources in GCP
// -- Traffic flows transparently across availibility zones.
//
// Along with the "primary" CIDR range, a subnet may optionally have a "secondary" range.
// -- This is useful if you have multiple services running on a VM and you want to assign each service a different IP address
// -- The VM will be assigned an internal IP from its subnet's "primary" CIDR range, 
//           while IPs from the "secondary" IP range can be allocated to its hosted services. 
//
// Routing tables are associated with VPC in GCP
// VPC comes with an optional subnet creation "Auto mode", where one subnet from each region is automatically created.
//------------------------------------------------------------

// Create the VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "${var.cluster_name}-vpc-network"
  project                 = "${var.project_id}"
  auto_create_subnetworks = false

  depends_on = [
    google_project_service.required_api_service
  ]
}

// Create the subnet
resource "google_compute_subnetwork" "subnetwork" {
  name          = "${var.cluster_name}-${var.region}-subnet"
  project       = "${var.project_id}"
  network       = google_compute_network.vpc_network.id
  region        = "${var.region}"

  private_ip_google_access = true

  // The following is called the "primary" IP range of the subnet
  // A GKE node internally is a GCP compute instance. Instances require IP for networking.
  // When a GKE node is created, it gets its internal IP address from this range.  
  ip_cidr_range = "${var.k8s_nodes_internal_ip_range}"
  
  // In a GKE cluster, worker nodes hosts pods and services
  // Pods and services, too, require IPs for networking
  // The "secondary IP" ranges of the subnet are used to assign IPs to pods and services
  secondary_ip_range {
    range_name    = "${var.cluster_name}-pod-ip-range"
    ip_cidr_range = "${var.k8s_pods_internal_ip_range}" 
  }

  secondary_ip_range {
    range_name    = "${var.cluster_name}-svc-ip-range"
    ip_cidr_range = "${var.k8s_services_internal_ip_range}"
  }
}


//--------------------------------------------------------------
// A private cluster is recommended over a public one
// In a GKE private cluster, the nodes only have internal IP addresses
// This means that nodes and Pods are isolated from the internet
//
// Changing a cluster to private pose these challenges:
//
// 1. The worker nodes will no longer have egress to the Internet. This will prevent pods from having external access.  
//      This can be a challenge, for example, if your pods containers are defined using images hosted in a public registry like DockerHub.
//         The pods will no longer be able to pull the images.
//    To restore this access, we will implement a "Cloud NAT" to provide egress.
//
// 2. Access to the Kubernetes API/the Control Plane will only be possible from within the VPC. 
//    We will deploy a "jumphost" -- a dedicated GCE instance in the VPC 
//      that will enable users (like admins and developers) to use SSH Tunneling to restore 'kubectl' access.
//-------------------------------------------------------------------

//--------------------------------------------------------------
// Create a NAT so that the nodes in the private cluster can reach DockerHub, etc
//--------------------------------------------------------------

// Create an external IP for NAT
// Why?
//  To communicate between instances on the same network, you can use an instance's internal IP. 
//  However, to communicate with the Internet, you must attach and use an external IP.
resource "google_compute_address" "nat_ip" {
  name    = "${var.cluster_name}-nat-ip"
  project = "${var.project_id}"
  region  = google_compute_subnetwork.subnetwork.region

  depends_on = [
    google_project_service.required_api_service
  ]
}

// Create a cloud router for use by the Cloud NAT
resource "google_compute_router" "cloud_router" {
  name    = "${var.cluster_name}-cloud-router"
  project = "${var.project_id}"
  network = google_compute_network.vpc_network.id
  region  = google_compute_subnetwork.subnetwork.region
  bgp {
    asn = 64514
  }
}

// Create a NAT
resource "google_compute_router_nat" "nat" {
  name    = "${var.cluster_name}-nat"
  project = "${var.project_id}"
  region  = google_compute_subnetwork.subnetwork.region
  router  = google_compute_router.cloud_router.name

  //Manually allocate the external IP
  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips = [google_compute_address.nat_ip.id]

  // "LIST_OF_SUBNETWORKS" - Only a list of Subnetworks are allowed to Nat 
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  //Configure which IPs in which subnet are allowed to Nat
  subnetwork {
    name                    = google_compute_subnetwork.subnetwork.id
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE", "LIST_OF_SECONDARY_IP_RANGES"]

    secondary_ip_range_names = [
      google_compute_subnetwork.subnetwork.secondary_ip_range.0.range_name, //pod ip range
      google_compute_subnetwork.subnetwork.secondary_ip_range.1.range_name, //service ip range
    ]
  }
}

//--------------------------------------------------------------
// Create a Jumphost
//--------------------------------------------------------------

locals {
  hostname = "${var.cluster_name}-jumphost"
}

// Dedicated service account for the jumphost instance
resource "google_service_account" "jumphost_sa" {
  account_id   = "${local.hostname}-sa"
  display_name = "Service account for instance ${local.hostname}"
}


// Create the jumphost
resource "google_compute_instance" "jumphost" {
  name         = "${local.hostname}"
  project      = "${var.project_id}"
  zone         = "${var.jumphost_zone}"
  machine_type = "e2-standard-2"
  tags         = ["jumphost"]

  // Specify the image to create the instance
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  // Additionally we deploy a tinyproxy daemon which allows kubectl commands to be piped through the bastion host
  // By default, tinyproxy whitelist 127.0.0.1 and listens for port 8888
  metadata_startup_script = "sudo apt-get update -y; sudo apt-get install -y tinyproxy;" 

  // Define a network interface in the correct subnet.
  network_interface {
    subnetwork = google_compute_subnetwork.subnetwork.name
  }

  // Allow the instance to be stopped by terraform when updating configuration
  allow_stopping_for_update = true

  service_account {
    email  = google_service_account.jumphost_sa.email
    scopes = ["cloud-platform"]
  }
}


// This module will create the necessary firewall rules and IAM bindings to allow SSH access to the jumphost via Tunneling
module "iap_tunneling" {
  source                     = "terraform-google-modules/bastion-host/google//modules/iap-tunneling"
  project                    = "${var.project_id}"
  network                    = google_compute_network.vpc_network.self_link
  
  //Firewall rule to create
  fw_name_allow_ssh_from_iap = "allow-ssh-from-iap-to-tunnel"
  
  service_accounts           = [google_service_account.jumphost_sa.email]
  
  //VM instance to bind the firewall rules and IAM bindings
  instances = [{
    name = google_compute_instance.jumphost.name
    zone = var.jumphost_zone
  }]
  
  // Members to allow instance access via SSH and IAP
  members = var.jumphost_users

  depends_on = [
    google_project_service.required_api_service
  ]
}

//--------------------------------------------------------------
// Create the GKE cluster
//--------------------------------------------------------------

resource "google_container_cluster" "cluster" {
  name                    = "${var.cluster_name}"
  project                 = "${var.project_id}"
  network                 = google_compute_network.vpc_network.id
  subnetwork              = google_compute_subnetwork.subnetwork.id

  // A GKE cluster can be regional or zonal
  // zonal clusters that have a single control plane in a single zone, 
  // regional clusters replicates both a cluster's control plane and its nodes across multiple zones in a region.
  // Pass a region to the key "location" to create a regional cluster
  // Pass a zone to the key "location" to create a zonal cluster
  location                = "${var.region}"

  // It is recommended that node pools be created and managed as separate resources
  // However, we can't create a cluster with no node pool defined, 
  // Solution: Create the smallest possible default node pool and immediately delete it.
  remove_default_node_pool = "true"
  initial_node_count       = 1

  // Configure the cluster to have private worker nodes and private control plane access only
  private_cluster_config {
    enable_private_endpoint = "true"
    enable_private_nodes    = "true"
    master_ipv4_cidr_block  = "172.16.0.16/28" //Control plane address range	
  }

  // Specify that the Kubernetes APIs are only accessible by the jumphost
  master_authorized_networks_config {
    cidr_blocks {
      display_name = "jumphost"
      cidr_block   = format("%s/32", google_compute_instance.jumphost.network_interface.0.network_ip)
    }
  }

  // Allocate IPs from the subnets
  ip_allocation_policy {
    // subnet's secondary CIDR range to be used for pod IP addresses
    cluster_secondary_range_name  = google_compute_subnetwork.subnetwork.secondary_ip_range.0.range_name
    // subnet's secondary CIDR range to be used for service IP addresses
    services_secondary_range_name = google_compute_subnetwork.subnetwork.secondary_ip_range.1.range_name
  }

  // Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  //Configure which logging service the cluster should write logs to. 
  //logging.googleapis.com/kubernetes = Stackdriver Kubernetes Engine Logging
  logging_service    = "logging.googleapis.com/kubernetes"

  //Configure which monitoring service the cluster should write metrics to. 
  //logging.googleapis.com/kubernetes = Stackdriver Kubernetes Engine Logging
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  // Configure various addons
  addons_config {
    
    horizontal_pod_autoscaling {
      disabled = false
    }

    // Enable network policy (Calico)
    network_policy_config {
      disabled = false
    }
  }

  // Disable basic authentication and cert-based authentication.
  master_auth {
    client_certificate_config {
      issue_client_certificate = "false"
    }
  }

  // Enable network policy configurations (like Calico) - for some reason this
  // has to be in here twice.
  network_policy {
    enabled = "true"
  }

  // Allow plenty of time for each operation to finish (default was 10m)
  timeouts {
    create = "30m"
    update = "30m"
    delete = "30m"
  }

  depends_on = [
    google_project_service.required_api_service,
    google_compute_router_nat.nat
  ]

}

# Google recommends a custom service account to manage node pools
resource "google_service_account" "gke-sa" {
  account_id        = "${var.cluster_name}-node-sa"
  display_name      = "GKE Security Service Account"
  project           = "${var.project_id}"
}

// A separately managed node pool where workloads will run.  
// A regional node pool will have "node_count" nodes per zone, and will use 3 zones. 
// This node pool will use a non-default service-account with minimal
// Oauth scope permissions.
resource "google_container_node_pool" "nodepool_standard" {
  name       = "nodepool-standard"
  location   = "${var.region}"
  cluster    = google_container_cluster.cluster.name
  node_count = "1"

  node_config {
    machine_type = "e2-standard-2"
    disk_type    = "pd-standard"
    disk_size_gb = 10
    image_type   = "COS_CONTAINERD"

    // Use the cluster created service account for this node pool
    service_account = google_service_account.gke-sa.email

    // Use the minimal oauth scopes needed
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/trace.append",
    ]

    labels = {
      cluster = var.cluster_name
    }

    // Enable workload identity on this node pool
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  // Repair any issues but don't auto upgrade node versions
  management {
    auto_repair  = "true"
    auto_upgrade = "true"
  }

  depends_on = [
    google_container_cluster.cluster
  ]
}