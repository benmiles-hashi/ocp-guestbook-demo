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
    aap = {
      source = "ansible/aap"
      version = "1.4.0-devpreview1"
    }
  }
}
provider "vault" {
  address = var.vault_address
  token   = var.vault_root_token
  namespace = var.vault_namespace
}
provider "aap" {
  # configure with your AAP/Tower host & credentials
  host = var.aap_hostname
  username = var.aap_username
  password = var.aap_password
  insecure_skip_verify = true
}