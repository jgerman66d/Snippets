resource "google_compute_startup_script" "samba_setup" {
  instance = var.instance_name

  content = <<-EOT
    #!/bin/bash
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y samba gcsfuse realmd sssd sssd-tools samba-common-bin krb5-user packagekit

    # Join Active Directory domain
    echo "${var.ad_admin_password}" | realm join --user="${var.ad_admin_username}" "${var.ad_domain}" -v --computer-ou="${var.ad_ou}" --install=/

    # Configure Samba for AD authentication
    sed -i 's/security = user/security = ads/g' /etc/samba/smb.conf
    echo "  realm = ${var.ad_domain}" >> /etc/samba/smb.conf
    echo "  password server = ${var.ad_domain_controller}" >> /etc/samba/smb.conf
    echo "  idmap config * : backend = tdb" >> /etc/samba/smb.conf
    echo "  idmap config * : range = 10000-99999" >> /etc/samba/smb.conf
    echo "  winbind use default domain = yes" >> /etc/samba/smb.conf
    echo "  winbind offline logon = false" >> /etc/samba/smb.conf

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
variable "ad_admin_username" {}
variable "ad_admin_password" {}
variable "ad_domain" {}
variable "ad_domain_controller" {}
variable "ad_ou" {}
variable "samba_username" {}
variable "samba_password" {}
variable "service_account_file" {}

