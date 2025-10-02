variable "cluster_id" {
  description = "ROSA cluster ID (not the OIDC ID)"
  type        = string
}
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

variable "vault_kv_mount" {
  description = "Vault KV v2 mount path where cluster metadata is stored"
  type        = string
  default     = "openshift"
}

variable "app_namespace" {
  description = "Kubernetes namespace (project) for the app"
  type        = string
  default     = "app-2"
}

variable "sa_name" {
  description = "ServiceAccount name for the app"
  type        = string
  default     = "my-app"
}
variable "database_username" {
  default = "admin"
}
variable "database_password" {
  type = string
}
variable "team_name" {
  description = "Logical team name for PKI role binding"
  type        = string
  default     = "team-b"
}

variable "pki_mount" {
  description = "Existing Vault PKI mount to issue certs from (intermediate)"
  type        = string
  default     = "pki_int"
}

variable "pki_allowed_domain" {
  description = "Base DNS domain for the team’s PKI role (e.g., tenant-1.example.com)"
  type        = string
  default     = "tenant-1.example.com"
}

variable "jwt_bound_audiences" {
  description = "Audiences accepted by Vault JWT role (VSO uses k8s default)"
  type        = list(string)
  default     = ["https://kubernetes.default.svc"]
}