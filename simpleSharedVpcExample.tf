provider "google" {
  project = "<YOUR-HOST-PROJECT-ID>"
  region  = "<YOUR-REGION>"
}

// Enable the necessary APIs for shared VPC
resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
}

resource "google_project_service" "servicenetworking" {
  service = "servicenetworking.googleapis.com"
}

// Create the shared VPC network
resource "google_compute_network" "shared_vpc_network" {
  name                    = "shared-vpc-network"
  auto_create_subnetworks = false
}

// Create a subnet in the shared VPC
resource "google_compute_subnetwork" "shared_vpc_subnet" {
  name          = "shared-vpc-subnet"
  ip_cidr_range = "10.0.0.0/16"
  network       = google_compute_network.shared_vpc_network.self_link
}

// Grant the host project permission to be a shared VPC host
resource "google_compute_shared_vpc_host_project" "host_project" {
  project = google_project_service.compute.project
}

// Outputs
output "shared_vpc_network" {
  value = google_compute_network.shared_vpc_network.name
}

output "shared_vpc_subnet" {
  value = google_compute_subnetwork.shared_vpc_subnet.name
}
