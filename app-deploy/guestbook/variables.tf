variable "vault_address" {
  type=string
}
variable "vault_token" {
  type=string
}
variable "vault_namespace" {
  description = "Vault namespace that holds KV and auth backends"
  type        = string
  default     = "admin"
}