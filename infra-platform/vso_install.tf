variable "operator_channel" {
  description = "VSO subscription channel."
  type        = string
  default     = "stable"
}

variable "operator_package" {
  description = "VSO operator package name."
  type        = string
  default     = "vault-secrets-operator"
}

variable "catalog_source" {
  description = "OLM catalog source."
  type        = string
  default     = "certified-operators"
}

variable "catalog_namespace" {
  description = "Namespace of the catalog source."
  type        = string
  default     = "openshift-marketplace"
}

locals {
  kv_mount         = "openshift-rosa-${module.rosa_hcp.cluster_id}"
  kv_config_path   = "config"
  oidc_issuer      = module.rosa_hcp.oidc_endpoint_url
  jwks_url         = "${trim(module.rosa_hcp.oidc_endpoint_url, "/")}/keys.json"
  # Extract hostname for TLS SNI where needed
  vault_host = replace(replace(var.vault_address, "https://", ""), ":8200", "")
}

########################################
# TLS discovery (no shell, all native)
########################################

# Fetch TLS chain for OIDC issuer (will connect to the URL and read chain)
data "tls_certificate" "oidc" {
  url = local.oidc_issuer
}

# Build a CA bundle (skip leaf cert if present)
# data.tls_certificate.certificates is a list from leaf -> chain
locals {
  oidc_ca_bundle = length(data.tls_certificate.oidc.certificates) > 1 ? join("", slice([for c in data.tls_certificate.oidc.certificates : c.cert_pem], 1, length(data.tls_certificate.oidc.certificates))) : ""
}

# Fetch TLS chain for Vault server to create a k8s Secret (ca.crt)
data "tls_certificate" "vault_addr" {
  url = var.vault_address
}

locals {
  vault_ca_bundle = length(data.tls_certificate.vault_addr.certificates) > 1 ? join("", slice([for c in data.tls_certificate.vault_addr.certificates : c.cert_pem], 1, length(data.tls_certificate.vault_addr.certificates))) : ""
}

########################################
# Install VSO (Subscription) + RBAC
########################################

resource "kubernetes_manifest" "vso_subscription" {
  manifest = {
    apiVersion = "operators.coreos.com/v1alpha1"
    kind       = "Subscription"
    metadata = {
      name      = var.operator_package
      namespace = "openshift-operators"
    }
    spec = {
      channel         = var.operator_channel
      name            = var.operator_package
      source          = var.catalog_source
      sourceNamespace = var.catalog_namespace
    }
  }
}

resource "kubernetes_manifest" "issuer_discovery_crb" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "service-account-issuer-discovery-unauthenticated"
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "system:service-account-issuer-discovery"
    }
    subjects = [{
      kind     = "Group"
      apiGroup = "rbac.authorization.k8s.io"
      name     = "system:unauthenticated"
    }]
  }
}

########################################
# Create k8s Secret for Vault CA and VaultConnection CR
########################################

resource "kubernetes_secret" "vault_cacert" {
  metadata {
    name      = "vault-cacert"
    namespace = "openshift-operators"
  }

  data = {
    "ca.crt" = base64encode(local.vault_ca_bundle)
  }

  type = "Opaque"
}

resource "kubernetes_manifest" "vault_connection" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultConnection"
    metadata = {
      name      = "default"
      namespace = "openshift-operators"
    }
    spec = {
      address        = var.vault_address
      tlsServerName  = local.vault_host
      caCertSecretRef = kubernetes_secret.vault_cacert.metadata[0].name
      skipTLSVerify  = false
    }
  }

  depends_on = [
    kubernetes_manifest.vso_subscription,
    kubernetes_secret.vault_cacert,
  ]
}

########################################
# Vault: write OIDC config to KVv2 and enable/configure JWT
########################################

# Write OIDC discovery info into HCP Vault KV v2
# This mirrors your Ansible vault_kv2_write of jwks_url and oidc_ca_chain
resource "vault_kv_secret_v2" "oidc_config" {
  mount = local.kv_mount
  name  = local.kv_config_path

  data_json = jsonencode({
    jwks_url      = local.jwks_url
    oidc_ca_chain = local.oidc_ca_bundle
  })
}

# Enable/configure JWT auth at 'vso'
resource "vault_jwt_auth_backend" "vso" {
  path               = "jwt-${module.rosa_hcp.cluster_id}"
  type               = "jwt"
  description        = "Vault Secrets Operator JWT auth for cluster: ${module.rosa_hcp.cluster_id}"
  oidc_discovery_url = local.oidc_issuer
  bound_issuer       = local.oidc_issuer
  default_role       = "ocp-${module.rosa_hcp.cluster_id}"
}

# Create a role for the operator controller manager SA(s)
# Adjust bound_subject if you want to restrict to a specific namespace
resource "vault_jwt_auth_backend_role" "vso_role" {
  backend         = vault_jwt_auth_backend.vso.path
  role_name       = "ocp-${module.rosa_hcp.cluster_id}"
  role_type       = "jwt"
  user_claim      = "sub"

  # Audiences typically include "vault" and sometimes the issuer itself; include both
  bound_audiences = ["vault", "https://${local.oidc_issuer}"]

  # Allow any namespace service account named vault-secrets-operator-controller-manager
  bound_subject   = "system:serviceaccount:*:vault-secrets-operator-controller-manager"

  token_policies  = ["vso-operator"]
  token_ttl       = 3600
}

# Optionally, ensure the policy exists (you can bring your own)
# Example minimal policy that allows VSO to read KV mounts in namespaces labeled/structured as needed.
# Comment this out if you already manage policy elsewhere.
resource "vault_policy" "vso_operator" {
  name = "vso-operator"
  policy = <<-EOT
    # Example: allow list/read under specific mounts/namespaces as you see fit
    path "${local.kv_mount}/data/*" {
      capabilities = ["read", "list"]
    }
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
  EOT
}

# Ensure role references the policy we just created
resource "vault_jwt_auth_backend_role" "vso_role_with_policy" {
  backend         = vault_jwt_auth_backend.vso.path
  role_name       = vault_jwt_auth_backend_role.vso_role.role_name
  role_type       = "jwt"
  user_claim      = "sub"
  bound_audiences = vault_jwt_auth_backend_role.vso_role.bound_audiences
  bound_subject   = vault_jwt_auth_backend_role.vso_role.bound_subject

  token_policies  = [vault_policy.vso_operator.name]
  token_ttl       = 3600

  lifecycle {
    replace_triggered_by = [
      vault_policy.vso_operator.policy,
    ]
  }
}