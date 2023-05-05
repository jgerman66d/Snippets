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

# Create a firewall rule to allow incoming SSH and NFS traffic
module "firewall" {
  source     = "./fabric/modules/net-vpc-firewall"
  project_id = "my-project"
  network    = google_compute_network.vm_network.name

  ingress_rules = {
    allow-ssh = {
      description = "Allow incoming SSH traffic"
      rules = [
        { protocol = "tcp", ports = ["22"] } # 22 for SSH
      ]
      targets = ["vm-instances"]
    }
    allow-nfs = {
      description = "Allow incoming NFS traffic"
      rules = [
        { protocol = "tcp", ports = ["111", "2049"] } # 111 and 2049 for NFS
      ]
      targets = ["vm-instances"]
    }
    allow-smb = {
      description = "Allow incoming SMB traffic"
      rules = [
        { protocol = "tcp", ports = ["445"] }, # 445 for SMB over TCP
        { protocol = "udp", ports = ["445"] } # 445 for SMB over UDP
      ]
      targets = ["vm-instances"]
    }
  }

  egress_rules = {
    allow-nfs = {
      description = "Allow outgoing NFS traffic"
      rules = [
        { protocol = "tcp", ports = ["2049"] } # 2049 for NFS
      ]
    }
    allow-smb = {
      description = "Allow outgoing SMB traffic"
      rules = [
        { protocol = "tcp", ports = ["445"] }, # 445 for SMB over TCP
        { protocol = "udp", ports = ["445"] } # 445 for SMB over UDP
      ]
    }
  }
}

# Apply the rules to the VM instances
resource "google_compute_firewall" "allow_ssh" {
  name        = "allow-ssh"
  network     = google_compute_network.vm_network.self_link
  target_tags = ["vm-instances"]

  source_ranges = ["10.42.21.13/7"] # Change to your IP address range.

  allow {
    protocol = "tcp"
    ports    = ["22"] # 22 for SSH
  }
}

resource "google_compute_firewall" "allow_nfs" {
  name        = "allow-nfs"
  network     = google_compute_network.vm_network.self_link
  target_tags = ["vm-instances"]

  source_ranges = ["10.42.21.13/7"] # Change to your IP address range.

  allow {
    protocol = "tcp"
    ports    = ["111", "2049"] # 111 and 2049 for NFS
  }
}

resource "google_compute_firewall" "allow_smb" {
  name        = "allow-smb"
  network     = google_compute_network.vm_network.self_link
  target_tags = ["vm-instances"]

  source_ranges = ["10.42.21.13/7"] # Change to your IP address range.

  allow {
    protocol = "tcp"
    ports    = ["445"] # 445 for SMB over TCP
  }
  allow {
    protocol = "udp"
    ports    = ["445"] # 445 for SMB over UDP
  }
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
    # Split out Metadata startup script to a static file.
    user_data = "${file("u2204lvgcfbud.sh")}"
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