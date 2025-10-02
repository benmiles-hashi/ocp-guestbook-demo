variable "namespace" {
  description = "Target Kubernetes namespace (project) for the app"
  type        = string
}

variable "vault_mount" {
  description = "Vault PKI mount path (e.g., pki_int)"
  type        = string
}

variable "vault_role" {
  description = "Vault PKI role to issue certificates (e.g., team-b)"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace (e.g., admin)"
  type        = string
  default     = "admin"
}

variable "common_name" {
  description = "Common Name for the certificate"
  type        = string
}
variable "tls_secret_name" {
  description = "Kubernetes secret name to store the issued cert/key"
  type        = string
  default     = "tls-cert"
}
variable "kv_secret_name" {
  description = "Kubernetes secret name to store the issued secret"
  type        = string
  default     = "secret-from-vault"
}
variable "vault_auth_ref" {
  description = "Reference to VaultAuth resource in the namespace"
  type        = string
  default     = "vault-auth"
}

variable "ttl" {
  description = "Requested certificate TTL"
  type        = string
  default     = "14d"
}

variable "vault_kv_mount" {
  description = "Vault KV v2 mount path where cluster metadata is stored"
  type        = string
  default     = "openshift"
}
variable "team_name" {
  description = "Logical team name for PKI role binding"
  type        = string
  default     = "team-b"
}
variable "expiry_offset" {
  description = "Time before expiry when VSO should refresh"
  type        = string
  default     = "10s"
}
variable "cluster_id" {
  
}
