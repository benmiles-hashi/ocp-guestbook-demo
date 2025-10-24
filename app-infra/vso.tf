# Use the alpha manifest resource for CRDs like VaultAuth
resource "kubernetes_manifest" "vault_auth" {
  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultAuth"
    "metadata" = {
      "name"      = "vault-auth"
      "namespace" = kubernetes_namespace.app.metadata[0].name
    }
    "spec" = {
      "namespace" = "admin/${data.vault_namespace.cluster_ns.path}"
      "method" = "jwt"
      "mount"  = local.jwt_auth_path
      "jwt" = {
        "role"           = "${var.app_namespace}-role"
        "serviceAccount" = kubernetes_service_account.app_sa.metadata[0].name
      }
    }
  }
}
