provider "mysql" {
  endpoint = "${data.vault_kv_secret_v2.rds.data["host"]}:${data.vault_kv_secret_v2.rds.data["port"]}"
  username = data.vault_generic_secret.rds_admin.data["username"]
  password = data.vault_generic_secret.rds_admin.data["password"]
}
data "vault_generic_secret" "rds_admin" {
    namespace = data.vault_namespace.cluster_ns.path
    path = "rosa-${var.cluster_id}-database/creds/rds-admin"
}
resource "mysql_database" "namespace_schema" {
  name = local.database_schema_name
}
output "db_schema_name" {
  value       = mysql_database.namespace_schema.name
  description = "Database schema created for the app namespace"
}
