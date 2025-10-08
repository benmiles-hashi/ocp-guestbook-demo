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
output "vault_jwt_auth_backend_role" {
  value = vault_jwt_auth_backend_role.app.role_name
}
output "vault_database_secret_backend_role" {
  value = vault_database_secret_backend_role.app1.name
}
output "database_host" {
  value = nonsensitive("${local.database_host}:${local.database_port}")
}
output "database_engine" {
  value = vault_database_secret_backend_role.app1.backend
}
