

# --- Get ROSA cluster secrets from Vault ---
data "vault_kv_secret_v2" "rosa_cluster_config" {
  mount     = "openshift-rosa-${var.cluster_id}"
  name      = "config"
  depends_on = [ aap_job.vso_install ]
}

# --- Enable JWT auth backend for this cluster ---
resource "vault_jwt_auth_backend" "jwt" {
  #namespace   = var.vault_namespace
  path        = "jwt-${var.cluster_id}"
  type        = "jwt"
  jwks_url    = data.vault_kv_secret_v2.rosa_cluster_config.data["jwks_url"]
  jwks_ca_pem = data.vault_kv_secret_v2.rosa_cluster_config.data["oidc_ca_chain"]

  #default_role = "my-app"
  depends_on = [ aap_job.vso_install ]
}
