
# Store RDS creds in Vault for reference
resource "vault_kv_secret_v2" "infra_rds" {
  namespace = vault_namespace.cluster_ns.path
  mount = vault_mount.secret.path
  name  = "rds"

  data_json = jsonencode({
    username    = aws_db_instance.demo.username
    password    = random_password.rds.result
    host        = aws_db_instance.demo.address
    port        = 3306
  })
  depends_on = [ aws_db_instance.demo ]
}

# Enable the database secrets engine if not already
resource "vault_mount" "db" {
  namespace = vault_namespace.cluster_ns.path
  path = "rosa-${module.rosa_hcp.cluster_id}-database"
  type = "database"
}

# Connection for RDS
resource "vault_database_secret_backend_connection" "rds" {
  namespace = vault_namespace.cluster_ns.path
  backend       = vault_mount.db.path
  name          = "rds-mysql-connection"
  allowed_roles = ["*"]

  mysql {
    connection_url = "{{username}}:{{password}}@tcp(${aws_db_instance.demo.address}:3306)/"
    username       = aws_db_instance.demo.username
    password       = random_password.rds.result
  }
  depends_on = [ aws_db_instance.demo, module.rosa_hcp ]
}
resource "vault_database_secret_backend_role" "rds_admin" {
  namespace = vault_namespace.cluster_ns.path
  backend = vault_mount.db.path
  name    = "rds-admin"
  db_name = vault_database_secret_backend_connection.rds.name

  creation_statements = [
    "CREATE USER '{{name}}'@'%' IDENTIFIED WITH mysql_native_password BY '{{password}}';",
    "GRANT CREATE, ALTER, DROP, INDEX, INSERT, UPDATE, DELETE, SELECT ON *.* TO '{{name}}'@'%';"
  ]

  default_ttl = 900
  max_ttl     = 3600
}
