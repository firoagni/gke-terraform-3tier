#-------------------------------------------------
#
# Required values to be set
#
#------------------------------------------------

variable "project_id" {
  description = "The ID of the project to host the resouces"
  type        = string
}

variable "region" {
  description = "The region in which to create the vpc network"
  type        = string
}

variable "jumphost_zone" {
  description = "The zone in which to create the jumphost. Must match the region"
  type        = string
}

#-------------------------------------------------
#
# Optional values that can be overridden
#
#------------------------------------------------

variable "jumphost_users" {
  description = "List of members in the standard GCP form: user:{email}, serviceAccount:{email}, group:{email}"
  type        = list(string)
  default     = [ "user:firoagni@gmail.com"]
}

variable "k8s_nodes_internal_ip_range" {
  description = "CIDR IP range for Kubernetes nodes"
  type        = string
  default     = "10.0.0.0/24"
}

variable "k8s_pods_internal_ip_range" {
  description = "CIDR IP range for Kubernetes nodes"
  type        = string
  default     = "10.1.0.0/16"
}

variable "k8s_services_internal_ip_range" {
  description = "CIDR IP range for Kubernetes nodes"
  type        = string
  default     = "10.2.0.0/20"
}

variable "cluster_name" {
  description = "The name of the Kubernetes cluster."
  type        = string
  default     = "private-cluster"
}