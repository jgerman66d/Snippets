provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_instance" "gcs_samba_server" {
  name         = "gcs-samba-server"
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  tags = ["gcs-samba-server"]
}

resource "google_compute_firewall" "allow_samba" {
  name    = "allow-samba"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["137", "138", "139", "445"]
  }

  source_ranges = var.allowed_source_ranges
  target_tags   = ["gcs-samba-server"]
}

module "samba_setup" {
  source = "./modules/samba_setup"

  instance_name        = google_compute_instance.gcs_samba_server.name
  gcs_buckets          = var.gcs_buckets
  samba_username       = var.samba_username
  samba_password       = var.samba_password
  service_account_file = var.service_account_file
}
