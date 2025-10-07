variable "vault_address" {
  type        = string
  description = "Address of the Vault server (e.g. http://127.0.0.1:8200)"
}

variable "vault_root_token" {
  type        = string
  description = "Root token (or bootstrap token) for Vault"
  sensitive   = true
}
variable "cluster_id" {
  description = "ROSA cluster ID"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace to configure JWT auth"
  type        = string
  default     = "admin"
}
variable "aap_hostname" {
  default = "https://54.185.32.221"
}
variable "aap_password" {
  default = "ansible123!"
}
variable "aap_username" {
  default = "admin"
}