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
