# The Google Cloud provider
provider "google" {
    project = "${var.project_id}"
    region  = "${var.region}"
}

# The Google Cloud provider -- Required for creating GKE cluster
provider "google-beta" {
    project = "${var.project_id}"
    region  = "${var.region}"
}