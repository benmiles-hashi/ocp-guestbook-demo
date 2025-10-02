variable "cluster_id" {
  description = "ROSA cluster ID"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace to configure JWT auth"
  type        = string
  default     = "admin"
}

variable "vault_kv_mount" {
  description = "KV v2 mount path where cluster metadata is stored"
  type        = string
  default     = "openshift"
}

# --- Get ROSA cluster secrets from Vault ---
data "vault_kv_secret_v2" "rosa_cluster_config" {
  mount     = var.vault_kv_mount
  name      = "rosa/${var.cluster_id}/config"
}
data "vault_kv_secret_v2" "rosa_cluster" {
  mount     = var.vault_kv_mount
  name      = "rosa/${var.cluster_id}/infra"
}
# --- Enable JWT auth backend for this cluster ---
resource "vault_jwt_auth_backend" "jwt" {
  #namespace   = var.vault_namespace
  path        = "jwt-${var.cluster_id}"
  type        = "jwt"
  jwks_url    = data.vault_kv_secret_v2.rosa_cluster_config.data["jwks_url"]
  jwks_ca_pem = data.vault_kv_secret_v2.rosa_cluster_config.data["oidc_ca_chain"]

  #default_role = "my-app"
}

# --- Vault Identity Entity (represents the app) ---
resource "vault_identity_entity" "my_app" {
  #namespace = var.vault_namespace
  name      = "my-app"

  metadata = {
    AppName          = "my-app"
    ClusterID        = var.cluster_id
    BusinessUnitName = "demo"
    TeamName         = "team-a"
  }
}

# --- Entity Alias to map OCP SA → Vault entity ---
resource "vault_identity_entity_alias" "my_app_alias" {
  #namespace      = var.vault_namespace
  name           = "system:serviceaccount:app-1:my-app"
  mount_accessor = vault_jwt_auth_backend.jwt.accessor
  canonical_id   = vault_identity_entity.my_app.id
}

# --- Example PKI policy with metadata substitution ---
resource "vault_policy" "pki" {
  #namespace = var.vault_namespace
  name      = "openshift-pki"

  policy = <<EOT
path "pki_int/issue/{{identity.entity.metadata.TeamName}}" {
  capabilities = ["create", "update"]
}
EOT
}

# --- JWT auth role bound to OCP SA ---
resource "vault_jwt_auth_backend_role" "my_app" {
  #namespace       = var.vault_namespace
  backend         = vault_jwt_auth_backend.jwt.path
  role_name       = "my-app"
  role_type       = "jwt"

  bound_audiences = [
    format("https://%s", trim(data.vault_kv_secret_v2.rosa_cluster.data["oidc_endpoint_url"], "/"))
  ]
  user_claim      = "sub"
  bound_subject   = "system:serviceaccount:app-1:my-app"

  token_policies  = [vault_policy.pki.name]
  token_ttl       = 3600
  token_max_ttl   = 7200
}
