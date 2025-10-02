terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.2.0"
    }
  }
  required_version = ">= 1.5.0"
}

variable "cluster_id" {
  description = "ROSA cluster ID (not the OIDC ID)"
  type        = string
  default = "2lit29efhda2oils244c820lep0sgg5m"
}

variable "vault_kv_mount" {
  description = "KV v2 mount where ROSA infra data is stored"
  type        = string
  default     = "openshift"
}

variable "sa_namespace" {
  description = "Namespace where the tf-admin SA lives"
  type        = string
  default     = "kube-system"
}

variable "sa_name_prefix" {
  description = "Prefix for the tf admin service account"
  type        = string
  default     = "tf-admin"
}

# Read ROSA infra secret from Vault KV v2:
# expected keys at openshift/rosa/<cluster_id>/infra:
#  - api_url (https://api....:443)
#  - token   (SA JWT created by your Ansible 'cluster-admin-setup' play)
#  - (optional) api_ca_pem (PEM for API server, if you captured it)
data "vault_kv_secret_v2" "infra" {
  mount = var.vault_kv_mount
  name  = "rosa/${var.cluster_id}/infra"
}

locals {
  api_url     = data.vault_kv_secret_v2.infra.data["api_url"]
  reviewer_jwt = data.vault_kv_secret_v2.infra.data["token"]
  # If you didn't store the API server CA, leave this empty string.
  api_ca_pem  = try(data.vault_kv_secret_v2.infra.data["api_ca_pem"], "")
}

# 1) Enable the Kubernetes *Secrets Engine* at a cluster-specific path
#resource "vault_mount" "k8s_sa_engine" {
#  path        = "kubernetes-admin-${var.cluster_id}"
#  type        = "kubernetes"
#  description = "Kubernetes SA token factory for ROSA cluster ${var.cluster_id}"
#}

# 2) Configure the engine: host, CA (optional), and the SA JWT with permissions
#    to create serviceaccount tokens (your cluster-admin SA token works).
resource "vault_kubernetes_secret_backend" "config" {

  path               = "kubernetes-admin-${var.cluster_id}"
  description = "Kubernetes SA token factory for ROSA cluster ${var.cluster_id}"
  kubernetes_host    = local.api_url
  kubernetes_ca_cert = local.api_ca_pem
  service_account_jwt = local.reviewer_jwt
  # disable_local_ca_jwt = true  # not needed here; leave default
}

# 3) Role that mints short-lived SA tokens for your tf-admin-<cluster_id> SA
#    You can widen namespaces to ["*"] if you prefer; keeping it tight here.
resource "vault_kubernetes_secret_backend_role" "terraform_admin" {
  backend = vault_kubernetes_secret_backend.config.path
  name    = "terraform-admin"

  service_account_name          = "${var.sa_name_prefix}-${var.cluster_id}"
  allowed_kubernetes_namespaces = [var.sa_namespace]

  # TTLs can be Go duration or seconds; strings are safest.
  token_default_ttl       = 21600
  token_max_ttl           = 43200
}

resource "vault_kv_secret_v2" "vault_meta" {
  mount = var.vault_kv_mount
  name  = "rosa/${var.cluster_id}/vault"

  data_json = jsonencode({
    k8s_engine_path = vault_kubernetes_secret_backend.config.path
    k8s_role        = vault_kubernetes_secret_backend_role.terraform_admin.name
  })
}

output "k8s_sa_engine_path" {
  value = vault_kubernetes_secret_backend.config.path
}

output "k8s_sa_role_name" {
  value = vault_kubernetes_secret_backend_role.terraform_admin.name
}

output "k8s_sa_subject" {
  value = "system:serviceaccount:${var.sa_namespace}:${var.sa_name_prefix}-${var.cluster_id}"
}
