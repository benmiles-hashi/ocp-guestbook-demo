terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.2.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "vault" {
  # Expect VAULT_ADDR / VAULT_TOKEN envs; set namespace here:
  address = var.vault_address
  token   = var.vault_token
  namespace = var.vault_namespace
}

provider "kubernetes" {
  host                   = local.api_url
  token                  = data.vault_kubernetes_service_account_token.tf_admin.service_account_token
  cluster_ca_certificate = local.api_ca_pem
}
