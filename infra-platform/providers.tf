terraform {
  cloud {
    organization = "ben-miles-org"
    workspaces {
      name = "ocp-infra-platform"
    }
  }  
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
    aap = {
      source  = "ansible/aap"
      version = "~> 1.0"   # check for latest
    }
  }
}
provider "aws" {
  region = "us-east-1"
}
provider "vault" {
  address = var.vault_address
  token   = var.vault_root_token
  namespace = var.vault_namespace
}
provider "rhcs" {
  token = var.redhat_token
}
provider "aap" {
  # configure with your AAP/Tower host & credentials
  host = var.aap_hostname
  username = var.aap_username
  password = var.aap_password
  insecure_skip_verify = true
}