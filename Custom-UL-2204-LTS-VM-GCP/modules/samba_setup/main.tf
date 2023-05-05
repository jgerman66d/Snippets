resource "google_compute_startup_script" "samba_setup" {
  instance = var.instance_name

  content = <<-EOT
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y samba gcsfuse

    # Create directories to mount GCS buckets
    ${formatlist("mkdir -p /mnt/gcs/%s", var.gcs_buckets)}

    # Mount GCS buckets using gcsfuse
    echo "${var.service_account_file}" > /tmp/service_account.json
    chown root:root /tmp/service_account.json
    chmod 600 /tmp/service_account.json

    ${formatlist("gcsfuse --key-file /tmp/service_account.json %s /mnt/gcs/%s", var.gcs_buckets, var.gcs_buckets)}

    # Configure Samba
    echo "[global]" > /etc/samba/smb.conf
    echo "  workgroup = WORKGROUP" >> /etc/samba/smb.conf
    echo "  server string = GCS Samba Server" >> /etc/samba/smb.conf
    echo "  log file = /var/log/samba/log.%m" >> /etc/samba/smb.conf
    echo "  max log size = 1000" >> /etc/samba/smb.conf
    echo "  security = user" >> /etc/samba/smb.conf
    echo "  passdb backend = tdbsam" >> /etc/samba/smb.conf
    echo "  load printers = no" >> /etc/samba/smb.conf
    echo "  printing = bsd" >> /etc/samba/smb.conf
    echo "  printcap name = /dev/null" >> /etc/samba/smb.conf
    echo "  disable spoolss = yes" >> /etc/samba/smb.conf
    echo "  dns proxy = no" >> /etc/samba/smb.conf
    echo "  unix extensions = no" >> /etc/samba/smb.conf
    echo "  acl allow execute always = true" >> /etc/samba/smb.conf

    # Create Samba shares for GCS buckets
    ${formatlist("echo \"[%s]\" >> /etc/samba/smb.conf", var.gcs_buckets)}
    ${formatlist("echo \"  comment = %s GCS Bucket\" >> /etc/samba/smb.conf", var.gcs_buckets)}
    ${formatlist("echo \"  path = /mnt/gcs/%s\" >> /etc/samba/smb.conf", var.gcs_buckets)}
    ${formatlist("echo \"  browsable = yes\" >> /etc/samba/smb.conf", var.gcs_buckets)}
    ${formatlist("echo \"  guest ok = no\" >> /etc/samba/smb.conf", var.gcs_buckets)}
    ${formatlist("echo \"  read only = no\" >> /etc/samba/smb.conf", var.gcs_buckets)}
    ${formatlist("echo \"  create mask = 0700\" >> /etc/samba/smb.conf", var.gcs_buckets)}
    ${formatlist("echo \"  directory mask = 0700\" >> /etc/samba/smb.conf", var.gcs_buckets)}
    ${formatlist("echo \"  valid users = %s\" >> /etc/samba/smb.conf", var.samba_username)}

    # Create Samba user
    echo -e "${var.samba_password}\n${var.samba_password}" | smbpasswd -a -s ${var.samba_username}

    # Start Samba
    systemctl restart smbd
    systemctl enable smbd
  EOT
}

variable "instance_name" {}
variable "gcs_buckets" {
  type = list(string)
}
variable "samba_username" {}
variable "samba_password" {}
variable "service_account_file" {}

