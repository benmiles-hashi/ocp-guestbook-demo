

# Vault provider (supply address and bootstrap token in tfvars or env vars)


# Generate a random password for the htpasswd IDP user
resource "random_password" "kubeadmin_password" {
  length  = 16
  special = true
}

# (Optional) Ensure KV v2 engine is enabled at "secret/"
resource "vault_mount" "secret" {
  namespace = vault_namespace.cluster_ns.path
  path = "openshift-rosa-${module.rosa_hcp.cluster_id}"
  type = "kv-v2"
}

# Write cluster info into Vault
resource "vault_kv_secret_v2" "rosa_cluster_info" {
  namespace = vault_namespace.cluster_ns.path
  mount = vault_mount.secret.path
  name  = "infra"

  data_json = jsonencode({
    username    = module.rosa_hcp.cluster_admin_username
    password    = module.rosa_hcp.cluster_admin_password
    api_url     = module.rosa_hcp.cluster_api_url
    oidc_endpoint_url = module.rosa_hcp.oidc_endpoint_url
    console_url = module.rosa_hcp.cluster_console_url
    cluster_id  = module.rosa_hcp.cluster_id
  })
  depends_on = [ module.rosa_hcp]
}

#########################################
# Root + Intermediate PKI Setup
#########################################

#########################################
# PKI Root + Intermediate per Namespace
#########################################

# ─── Root CA ──────────────────────────────────────────────
resource "vault_mount" "pki_root" {
  path      = "ocp-pki-root"
  type      = "pki"
  max_lease_ttl_seconds = 315360000  # 10 years
}

resource "vault_pki_secret_backend_root_cert" "root_ca" {
  backend       = vault_mount.pki_root.path
  type          = "internal"
  common_name   = "OCP Root CA"
  ttl           = "87600h"  # 10 years
  key_type      = "rsa"
  key_bits      = 4096
  exclude_cn_from_sans = true
  depends_on    = [vault_mount.pki_root]
}

# ─── Intermediate CA ──────────────────────────────────────
resource "vault_mount" "pki_int" {
  namespace = vault_namespace.cluster_ns.path
  path      = "ocp-pki-int"
  type      = "pki"
  max_lease_ttl_seconds = 157680000  # 5 years
}

# Create a CSR for the intermediate CA
resource "vault_pki_secret_backend_intermediate_cert_request" "int_csr" {
  namespace   = vault_namespace.cluster_ns.path
  backend     = vault_mount.pki_int.path
  type        = "internal"
  common_name = "OCP Intermediate CA"
  key_type    = "rsa"
  key_bits    = 4096
  depends_on  = [vault_mount.pki_int]
}

# Sign intermediate CSR with the root CA
resource "vault_pki_secret_backend_root_sign_intermediate" "int_signed" {
  #namespace   = vault_namespace.cluster_ns.path
  backend     = vault_mount.pki_root.path
  csr         = vault_pki_secret_backend_intermediate_cert_request.int_csr.csr
  common_name = "OCP Intermediate CA"
  ttl         = "43800h"  # 5 years
  depends_on  = [vault_pki_secret_backend_intermediate_cert_request.int_csr]
}

# Upload the signed intermediate certificate
resource "vault_pki_secret_backend_intermediate_set_signed" "int_set" {
  namespace   = vault_namespace.cluster_ns.path
  backend     = vault_mount.pki_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.int_signed.certificate
  depends_on  = [vault_pki_secret_backend_root_sign_intermediate.int_signed]
}

# ─── Configure URLs for intermediate ──────────────────────
resource "vault_pki_secret_backend_config_urls" "int_urls" {
  namespace                = vault_namespace.cluster_ns.path
  backend                  = vault_mount.pki_int.path
  issuing_certificates     = ["${var.vault_address}/v1/${vault_mount.pki_int.path}/ca"]
  crl_distribution_points  = ["${var.vault_address}/v1/${vault_mount.pki_int.path}/crl"]
  depends_on               = [vault_pki_secret_backend_intermediate_set_signed.int_set]
}

# ─── Create a Server TLS Role ─────────────────────────────
resource "vault_pki_secret_backend_role" "server_tls" {
  namespace        = vault_namespace.cluster_ns.path
  backend          = vault_mount.pki_int.path
  name             = "server-tls"
  allowed_domains  = ["svc.cluster.local"]
  allow_subdomains = true
  allow_bare_domains = true
  key_type         = "rsa"
  key_bits         = 2048
  server_flag      = true
  client_flag      = false
  ttl              = "720h"
  max_ttl          = "720h"
  generate_lease   = true
  depends_on       = [vault_pki_secret_backend_intermediate_set_signed.int_set]
}

# ─── Outputs (Optional) ───────────────────────────────────
output "ocp_pki_root" {
  value = vault_mount.pki_root.path
}

output "ocp_pki_int" {
  value = vault_mount.pki_int.path
}

output "ocp_server_role" {
  value = vault_pki_secret_backend_role.server_tls.name
}
