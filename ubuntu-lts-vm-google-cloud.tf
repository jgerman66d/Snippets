# Declare required providers
# Replace <YOUR-GOOGLE-APPLICATION-CREDENTIALS-JSON-FILE> and <YOUR-GCP-PROJECT-ID> 
provider "google" {
  credentials = file("<YOUR-GOOGLE-APPLICATION-CREDENTIALS-JSON-FILE>")
  project     = "<YOUR-GCP-PROJECT-ID>"
  region      = "us-central1"
}

# Define the latest Ubuntu LTS image family
data "google_compute_image" "ubuntu_lts" {
  family  = "ubuntu-2204-lts" # Ubuntu 22.04 LTS
  project = "ubuntu-os-cloud"
}

# Create a VPC network for the VM
resource "google_compute_network" "vm_network" {
  name = "vm-network"

  # Enable auto-subnet creation
  auto_create_subnetworks = true

  # Add a description to the network
  description = "VPC network for the Ubuntu VM"
}

# Create a firewall rule to allow incoming SSH and NFS traffic
resource "google_compute_firewall" "allow_ssh_nfs" {
  name    = "allow-ssh-nfs"
  network = google_compute_network.vm_network.self_link

  # Allow incoming SSH and NFS traffic
  allow {
    protocol = "tcp"
    ports    = ["22", "111", "2049"] # 22 for SSH, 111 and 2049 for NFS
  }

  # Apply the rule to the VM instances
  source_ranges = ["0.0.0.0/0"]
}

# Create a Google Cloud Filestore instance
resource "google_filestore_instance" "filestore" {
  name = "filestore-instance"
  tier = "BASIC_HDD" # Choose a tier based on your performance and storage needs
  zone = "us-central1-c"

  file_shares {
    name       = "nfs-share"
    capacity_gb = 1024 # Set the capacity based on your storage requirements
  }

  networks {
    network = google_compute_network.vm_network.self_link
    modes   = ["MODE_IPV4"]
  }
}

# Create a production virtual machine instance with recommended specifications
resource "google_compute_instance" "ubuntu_vm" {
  name         = "ubuntu-vm"
  machine_type = "e2-standard-4" # 4 vCPUs, 16 GB memory (recommended for production use)
  zone         = "us-central1-a"

  # Define the boot disk
  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_lts.self_link
    }
  }

  # Define the network interface
  network_interface {
    network = google_compute_network.vm_network.self_link

    # Assign a public IP to the VM
    access_config {
      // No additional settings needed
    }
  }

  # Use a startup script to mount the Filestore instance
  metadata_startup_script = <<-EOT
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y nfs-common
    sudo mkdir -p /mnt/nfs
    sudo chmod 777 /mnt/nfs
    sudo echo "${google_filestore_instance.filestore.networks.0.ip_addresses.0}:/nfs-share /mnt/nfs nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
    sudo mount -a
  EOT

  # Add metadata to the VM
  metadata = {
        "description" = "Production Ubuntu 22.04 LTS VM"
    } 
    # Use the default service account with the necessary scopes
    service_account {
        scopes = [
            "https://www.googleapis.com/auth/cloud-platform",
        ]
    }

# Enable deletion protection for production
    deletion_protection = true
}

