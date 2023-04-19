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

# # Create a VPC network for the VM
# # Will be created seperately from this file
# resource "google_compute_network" "vm_network" {
#   name = "vm-network"

#   # Enable auto-subnet creation
#   auto_create_subnetworks = true

#   # Add a description to the network
#   description = "VPC network for the Ubuntu VM"
# }


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

  # Source ranges default to ["0.0.0.0/0"] if not specified
  allow {
    protocol = "tcp"
    ports    = ["22"] # 22 for SSH
  }
}

resource "google_compute_firewall" "allow_nfs" {
  name        = "allow-nfs"
  network     = google_compute_network.vm_network.self_link
  target_tags = ["vm-instances"]

  # Source ranges default to ["0.0.0.0/0"] if not specified
  allow {
    protocol = "tcp"
    ports    = ["111", "2049"] # 111 and 2049 for NFS
  }
}

resource "google_compute_firewall" "allow_smb" {
  name        = "allow-smb"
  network     = google_compute_network.vm_network.self_link
  target_tags = ["vm-instances"]

  # Source ranges default to ["0.0.0.0/0"] if not specified
  allow {
    protocol = "tcp"
    ports    = ["445"] # 445 for SMB over TCP
  }
  allow {
    protocol = "udp"
    ports    = ["445"] # 445 for SMB over UDP
  }
}

# # Create a firewall rule to allow incoming SSH and NFS traffic
# resource "google_compute_firewall" "allow_ssh_nfs" {
#   name    = "allow-ssh-nfs"
#   network = google_compute_network.vm_network.self_link

#   # Allow incoming SSH and NFS traffic
#   allow {
#     protocol = "tcp"
#     ports    = ["22", "111", "2049"] # 22 for SSH, 111 and 2049 for NFS
#   }

#   # Apply the rule to the VM instances
#   source_ranges = ["0.0.0.0/0"]
# }

# Creates a Google Cloud Storage instance using fabric module
# This probably will not be used, instead use file store model below.
# module "poc_bucket" {  # Change
#   source     = "./fabric/modules/net-filestore"
#   project_id = "my-project"
#   name       = "poc-bucket" # Change
#   prefix     = "test" # Change
#   zone       = "us-central1-c"
#   tier       = "BASIC_HDD" # Choose a tier based on your performance and storage needs
#   capacity   = 1024 # Set the capacity based on your storage requirements
#   versioning = "true"
#   labels     = {
#     environment = "production"
#   } 
#   iam        = {
#     "roles/storage.admin" = ["group:storage@example.com"]
#   }
#   storage_class = "STANDARD" # Choose a storage class based on your performance and storage needs, STANDARD or NEARLINE
#   retention_policy = {
#     is_locked        = false     # Unlock the retention policy, Locking the retention policy prevents changes to the retention period
#     retention_period = 315576000 # 10 years in seconds
#   }
#   # Set the default KMS key to use for encryption, if not set, Google-managed encryption keys are used, which are not recoverable, and cannot be shared with other projects, or moved to a different location, or deleted, unless the object is deleted, or the bucket is deleted, and all objects are deleted, and the retention policy is locked,   https://cloud.google.com/storage/docs/encryption/using-customer-managed-keys
#   # Not enabled by default or for this bucket.
#   #   encryption = {
#   #     default_kms_key_name = "projects/my-project/locations/us-central1/keyRings/my-key-ring/cryptoKeys/my-key"
#   #   } 
#   uniform_bucket_level_access = true # Enable uniform bucket-level access, which provides a uniform access policy for all objects in the bucket
# }


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
    # Install NFS and Active Directory required packages
    sudo apt-get install -y nfs-common realmd sssd sssd-tools adcli krb5-user packagekit
    sudo mkdir -p /mnt/nfs
    sudo chmod 777 /mnt/nfs
    sudo echo "${google_filestore_instance.filestore.networks.0.ip_addresses.0}:/nfs-share /mnt/nfs nfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
    sudo mount -a

    # Install the Google Cloud SDK
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    sudo apt-get install apt-transport-https ca-certificates gnupg
    sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg adv --keyserver keyserver.ubuntu.com --recv-keys CC86BB64
    sudo apt-get update && sudo apt-get install google-cloud-sdk

    # Configure Active Directory integration
    # Replace the following placeholders with your actual domain details
    DOMAIN_NAME="<YOUR-AD-DOMAIN-NAME>"
    DOMAIN_REALM="$${DOMAIN_NAME^^$}"
    PROJECT_ID="<YOUR-PROJECT-ID>"
    SECRET_USERNAME_NAME="<AD-USERNAME-SECRET-NAME>"
    SECRET_PASSWORD_NAME="<AD-PASSWORD-SECRET-NAME>"

    # Fetch secrets from Google Secret Manager
    DOMAIN_ADMIN_USER="$(gcloud secrets versions access latest --secret=$SECRET_USERNAME_NAME --project=$PROJECT_ID)"
    DOMAIN_ADMIN_PASS="$(gcloud secrets versions access latest --secret=$SECRET_PASSWORD_NAME --project=$PROJECT_ID)"
    DOMAIN_REALM="$${DOMAIN_NAME^^$}"

    # Install necessary packages for Active Directory authentication
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y samba sssd-ad

    # Join the domain using realm
    echo "${DOMAIN_ADMIN_PASS}" | sudo realm join --verbose --user="${DOMAIN_ADMIN_USER}" "${DOMAIN_NAME}"

    # Enable home directory creation for domain users
    echo "session required pam_mkhomedir.so skel=/etc/skel umask=0022" | sudo tee -a /etc/pam.d/common-session

    # Restart the sssd service
    sudo systemctl restart sssd

    # Configure SMB to work with Active Directory
    sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.bak
    sudo bash -c "cat > /etc/samba/smb.conf << EOL
    [global]
      workgroup = $${DOMAIN_NAME^^$}
      security = ADS
      realm = ${DOMAIN_REALM}
      log file = /var/log/samba/%m.log
      kerberos method = secrets and keytab

    [homes]
      comment = Home Directories
      valid users = %S, %D%w%S
      browseable = No
      read only = No
      inherit acls = Yes
      inherit permissions = Yes
      inherit owner = Yes
    EOL"

    # Restart the smbd service
    sudo systemctl restart smbd
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

