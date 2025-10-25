terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~>5.3.0"
    }
  }
}
provider "vault" {
  address = var.vault_address
  #token   = var.vault_root_token
  namespace = var.vault_namespace
}

# ─── Root CA ──────────────────────────────────────────────
resource "vault_mount" "pki_root" {
  path      = "ocp-pki-root"
  type      = "pki"
  max_lease_ttl_seconds = 315360000 

}

resource "vault_pki_secret_backend_root_cert" "root_ca" {
  backend       = vault_mount.pki_root.path
  type          = "internal"
  common_name   = "OCP Root CA"
  ttl           = "87600h" 
  key_type      = "rsa"
  key_bits      = 4096
  exclude_cn_from_sans = true

  depends_on    = [vault_mount.pki_root]
}