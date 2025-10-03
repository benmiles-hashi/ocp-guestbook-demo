terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "3.25.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = ">=1.7.1" # or whatever version you need
    }
  }
}

# Vault provider (supply address and bootstrap token in tfvars or env vars)
provider "vault" {
  address = var.vault_address
  token   = var.vault_root_token
  namespace = var.vault_namespace
}

# Generate a random password for the htpasswd IDP user
resource "random_password" "kubeadmin_password" {
  length  = 16
  special = true
}

# (Optional) Ensure KV v2 engine is enabled at "secret/"
resource "vault_mount" "secret" {
  path = "openshift-rosa-${module.rosa_hcp.cluster_id}"
  type = "kv-v2"
}

# Write cluster info into Vault
resource "vault_kv_secret_v2" "rosa_cluster_info" {
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
