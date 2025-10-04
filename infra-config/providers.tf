terraform {
  cloud {
    organization = "ben-miles-org"
    workspaces {
      name = "ocp-infra-config"
    }
  }  
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~>5.3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}
provider "vault" {
  address = var.vault_address
  token   = var.vault_root_token
  namespace = var.vault_namespace
}