variable "project_id" {}
variable "region" {}
variable "zone" {}
variable "machine_type" {}
variable "public_key_path" {}
variable "service_account_email" {}
variable "gcs_buckets" {
  type = list(string)
}
variable "samba_username" {}
variable "samba_password" {}
variable "service_account_file" {}
variable "allowed_source_ranges" {
  type = list(string)
}
variable "ad_admin_username" {}
variable "ad_admin_password" {}
variable "ad_domain" {}
variable "ad_domain_controller" {}
variable "ad_ou" {}
