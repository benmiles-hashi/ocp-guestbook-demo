output "namespace" {
  value = kubernetes_namespace.app.metadata[0].name
}

output "service_account" {
  value = kubernetes_service_account.app_sa.metadata[0].name
}

output "vault_auth_mount" {
  value = local.jwt_auth_path
}

output "vault_entity_id" {
  value = vault_identity_entity.app.id
}

output "pki_role_path" {
  value = "${var.pki_mount}/issue/${var.team_name}"
}
