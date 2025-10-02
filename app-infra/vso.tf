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
      "namespace" = var.vault_namespace
      "method" = "jwt"
      # This must be the mount *path*, not "auth/<path>"
      "mount"  = local.jwt_auth_path
      "jwt" = {
        "role"           = var.app_namespace         # we'll create a Vault JWT role with same name
        "serviceAccount" = kubernetes_service_account.app_sa.metadata[0].name
      }
    }
  }
}
