terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
  }
}
data "vault_kv_secret_v2" "infra" {
  mount = "openshift"
  name  = "rosa/${var.cluster_id}/infra"
}

# Ask Vault's Kubernetes secrets engine for a short-lived SA token
data "vault_kubernetes_service_account_token" "admin" {
  backend              = "kubernetes-admin-${var.cluster_id}"
  role                 = "terraform-admin"
  kubernetes_namespace = "kube-system"
  ttl                  = "1h"
}

provider "kubernetes" {
  host                   = data.vault_kv_secret_v2.infra.data["api_url"]
  cluster_ca_certificate = data.vault_kv_secret_v2.infra.data["api_ca_pem"]
  token                  = data.vault_kubernetes_service_account_token.admin.service_account_token
}


resource "kubernetes_manifest" "vault_pki_secret" {
  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultPKISecret"
    "metadata" = {
      "name"      = "vault-pki-${var.namespace}"
      "namespace" = var.namespace
    }
    "spec" = {
      "namespace"     = var.vault_namespace
      "mount"         = var.vault_mount
      "role"          = var.vault_role
      "commonName"    = var.common_name
      "format"        = "pem"
      "revoke"        = false
      "clear"         = true
      "expiryOffset"  = var.expiry_offset
      "ttl"           = var.ttl
      "vaultAuthRef"  = var.vault_auth_ref

      "destination" = {
        "name"  = var.tls_secret_name
        "type"  = "kubernetes.io/tls"
        "create" = true
      }
    }
  }
}

resource "kubernetes_manifest" "vault_kv_secret" {
  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultStaticSecret"
    "metadata" = {
      "name"      = "vault-kv-${var.namespace}"
      "namespace" = var.namespace
    }
    "spec" = {
      "namespace"    = var.vault_namespace
      "mount"        = var.vault_kv_mount
      "path"         = "rosa/${var.cluster_id}/apps/${var.namespace}/${var.team_name}/secretdata"
      "type"         = "kv-v2"
      "vaultAuthRef" = var.vault_auth_ref

      "destination" = {
        "name"   = var.kv_secret_name
        "type"   = "Opaque"
        "create" = true
      }
    }
  }
}
resource "kubernetes_manifest" "db_creds" {
  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultStaticSecret"
    "metadata" = {
      "name"      = "db-creds-${var.namespace}"
      "namespace" = var.namespace
    }
    "spec" = {
      "namespace"    = var.vault_namespace
      "mount"        = var.vault_kv_mount
      "path"         = "rosa/${var.cluster_id}/apps/${var.namespace}/${var.team_name}/db_creds"
      "type"         = "kv-v2"
      "vaultAuthRef" = var.vault_auth_ref

      "destination" = {
        "name"   = "db-creds-${var.namespace}"
        "type"   = "Opaque"
        "create" = true
      }
    }
  }
}
resource "kubernetes_manifest" "db_dynamic_creds" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultDynamicSecret"
    metadata = {
      name      = "db-creds-dynamic-${var.namespace}"
      namespace = var.namespace
    }
    spec = {
      vaultAuthRef     = var.vault_auth_ref
      mount            = "rosa-${var.cluster_id}-database"
      path             = "creds/${var.namespace}-role"
      allowStaticCreds = true
      destination = {
        create = true
        name   = "db-dynamic-creds-${var.namespace}"
      }
      refreshAfter = "5m"
    }
  }
}