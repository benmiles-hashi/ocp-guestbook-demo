# Cluster infra: api_url, api_ca_pem (from your Ansible stage)
data "vault_kv_secret_v2" "infra" {
  mount = var.vault_kv_mount
  name  = "rosa/${var.cluster_id}/infra"
}

# Vault-side paths for k8s engine/role (and optional jwt auth path)
data "vault_kv_secret_v2" "vault_meta" {
  mount = var.vault_kv_mount
  name  = "rosa/${var.cluster_id}/vault"
}

locals {
  api_url          = data.vault_kv_secret_v2.infra.data["api_url"]
  api_ca_pem       = try(data.vault_kv_secret_v2.infra.data["api_ca_pem"], "")
  k8s_engine_path  = data.vault_kv_secret_v2.vault_meta.data["k8s_engine_path"]
  k8s_role_name    = data.vault_kv_secret_v2.vault_meta.data["k8s_role"]
  jwt_aud = try(
    format("https://%s", data.vault_kv_secret_v2.infra.data["oidc_endpoint_url"]),
    "https://kubernetes.default.svc"
  )
  # If you didn't store jwt_auth_path in KV, we'll default it:
  jwt_auth_path    = try(data.vault_kv_secret_v2.vault_meta.data["jwt_auth_path"], "jwt-${var.cluster_id}")
}

# Mint a short-lived admin token for TF to talk to the cluster
data "vault_kubernetes_service_account_token" "tf_admin" {
  backend              = local.k8s_engine_path
  role                 = local.k8s_role_name
  kubernetes_namespace = "kube-system"   # matches your SA location in cluster-admin setup
  cluster_role_binding = false            # we set role type to ClusterRole in that stage
  ttl                  = "30m"
}
