variable "vault_address" {
  type        = string
  description = "Address of the Vault server (e.g. http://127.0.0.1:8200)"
}

variable "vault_root_token" {
  type        = string
  description = "Root token (or bootstrap token) for Vault"
  sensitive   = true
}
variable "vault_namespace" {
 type= string
 default = "admin"
}