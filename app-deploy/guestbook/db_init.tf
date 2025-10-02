terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29.0"
    }
  }
}
provider "vault" {
  # Expect VAULT_ADDR / VAULT_TOKEN envs; set namespace here:
  address = var.vault_address
  token   = var.vault_token
  namespace = var.vault_namespace
}
data "vault_kv_secret_v2" "infra" {
  mount = "openshift"
  name  = "rosa/${var.cluster_id}/infra"
}
data "vault_kv_secret_v2" "rds_info" {
  mount = "openshift"
  name  = "rosa/${var.cluster_id}/infra/rds"
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

variable "app_namespace" {
  description = "Namespace for the app and DB schema"
  type        = string
  default     = "guestbook"
}

variable "db_creds_secret_name" {
  description = "Name of the Kubernetes secret containing DB credentials (from VSO)"
  type        = string
  default     = "db-dynamic-creds-guestbook"
}
variable "cluster_id" {
  default = "2lit29efhda2oils244c820lep0sgg5m"
}
resource "kubernetes_manifest" "guestbook_db_init" {
  manifest = {
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = "guestbook-db-init"
      namespace = var.app_namespace
    }
    spec = {
      backoffLimit = 3
      template = {
        spec = {
          restartPolicy = "OnFailure"
          containers = [
            {
              name  = "mysql-init"
              image = "registry.redhat.io/rhel8/mysql-80"
              env = [
                {
                  name = "DB_USER"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.db_creds_secret_name
                      key  = "username"
                    }
                  }
                },
                {
                  name = "DB_PASSWORD"
                  valueFrom = {
                    secretKeyRef = {
                      name = var.db_creds_secret_name
                      key  = "password"
                    }
                  }
                },
                {
                  name  = "DB_HOST"
                  value = data.vault_kv_secret_v2.rds_info.data["host"]
                }
              ]
              command = ["/bin/sh", "-c"]
              args = [
                <<-EOT
                set -euo pipefail
                echo "Waiting for MySQL..."
                for i in $(seq 1 30); do
                  if mysql -h "$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
                    break
                  fi
                  echo "Retrying..."
                  sleep 5
                done
                echo "Initializing schema for ${var.app_namespace}..."
                mysql -h "$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" <<EOSQL
                CREATE DATABASE IF NOT EXISTS \`${var.app_namespace}\`;
                USE \`${var.app_namespace}\`;

                CREATE TABLE IF NOT EXISTS guestbook (
                  id INT AUTO_INCREMENT PRIMARY KEY,
                  name VARCHAR(100) NOT NULL,
                  message TEXT NOT NULL,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                EOSQL
                echo "Schema applied successfully."
                exit 0
                EOT
              ]
            }
          ]
        }
      }
    }
  }
}