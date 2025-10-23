# Look up the JWT auth backend to get its accessor (needed for entity alias)
data "vault_auth_backend" "jwt" {
  namespace = data.vault_namespace.cluster_ns.path
  path = local.jwt_auth_path
}
resource "random_id" "postfix" {
  byte_length = 6
}
# Vault entity representing the app
resource "vault_identity_entity" "app" {
  namespace = data.vault_namespace.cluster_ns.path
  name = "${var.app_namespace}-${random_id.postfix.hex}"

  metadata = {
    AppName   = var.app_namespace
    TeamName  = var.team_name
    ClusterID = var.cluster_id
  }
}

# Map OCP SA -> Vault entity via JWT auth accessor
resource "vault_identity_entity_alias" "app_alias" {
  namespace = data.vault_namespace.cluster_ns.path
  name           = "system:serviceaccount:${var.app_namespace}:${var.sa_name}"
  canonical_id   = vault_identity_entity.app.id
  mount_accessor = data.vault_auth_backend.jwt.accessor
}

# PKI Role under pki_int for this team
resource "vault_pki_secret_backend_role" "team_pki_role" {
  namespace = data.vault_namespace.cluster_ns.path
  backend          = var.pki_mount
  name             = var.team_name
  allowed_domains  = [var.pki_allowed_domain]
  allow_subdomains = true
  ttl              = "5m"
  max_ttl          = "1h"
  key_type         = "rsa"
  key_bits         = 2048
}

# Policy allowing issuance for this team's PKI role
resource "vault_policy" "pki_team" {
  namespace = data.vault_namespace.cluster_ns.path
  name   = "pki-${var.app_namespace}-${var.team_name}"
  policy = <<EOT
path "${var.pki_mount}/issue/${var.team_name}" {
  capabilities = ["create", "update"]
}
EOT
}
resource "vault_policy" "kv_app" {
  namespace = data.vault_namespace.cluster_ns.path
  name   = "kv-${var.team_name}-${var.app_namespace}"
  policy = <<EOT
path "${local.vault_kv_mount}/data/apps/${var.team_name}/${var.app_namespace}/*" {
  capabilities = ["read", "create", "update"]
}
EOT
}
resource "vault_policy" "db_app" {
  namespace = data.vault_namespace.cluster_ns.path
  name   = "db-${var.app_namespace}-${var.team_name}"
  policy = <<EOT
path "rosa-${var.cluster_id}-database/creds/${var.app_namespace}-role" {
  capabilities = ["read"]
}
EOT
}

# JWT role for the app namespace/serviceaccount
resource "vault_jwt_auth_backend_role" "app" {
  namespace = data.vault_namespace.cluster_ns.path
  backend         = local.jwt_auth_path
  role_name       = "${var.app_namespace}-role"
  role_type       = "jwt"

  # OpenShift/K8s default audience for projected SA tokens
    bound_audiences = [local.jwt_aud]


  # Bind to the SA identity
  user_claim    = "sub"
  bound_subject = "system:serviceaccount:${var.app_namespace}:${var.sa_name}"

  # Apply PKI policy
  token_policies = [
    vault_policy.pki_team.name,
    vault_policy.kv_app.name,
    vault_policy.db_app.name
  ]

  token_ttl     = 3600
  token_max_ttl = 7200
}

###
# Create test db variables
####
resource "vault_kv_secret_v2" "app_static_db" {
  namespace = data.vault_namespace.cluster_ns.path
  mount = local.vault_kv_mount
  name  = "apps/${var.team_name}/${var.app_namespace}/db_creds"

  data_json = jsonencode({
    username    = var.database_username
    password    = var.database_password
  })

}
resource "vault_kv_secret_v2" "app_kv" {
  namespace = data.vault_namespace.cluster_ns.path
  mount = local.vault_kv_mount
  name  = "apps/${var.team_name}/${var.app_namespace}/secretdata"

  data_json = jsonencode({
    message                 = "Hi.  I'm a vault secret"
    supersecretpassword     = "Sup3rS3cr3tP@ssw0rd!!@"
  })
  
}

###DB Role

resource "vault_database_secret_backend_role" "app1" {
  namespace = data.vault_namespace.cluster_ns.path
  backend = "rosa-${var.cluster_id}-database"
  name    = "${var.app_namespace}-role"
  db_name = "rds-mysql-connection"

  creation_statements = [
    "CREATE USER '{{name}}'@'%' IDENTIFIED WITH mysql_native_password BY '{{password}}';",
    "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP ON `${local.database_schema_name}`.* TO '{{name}}'@'%';"
  ]
  revocation_statements = [
    "DROP USER IF EXISTS '{{name}}'@'%';"
  ]
  default_ttl = 120
  max_ttl     = 120
}

####Kubernetes Role
resource "vault_kubernetes_secret_backend_role" "terraform_admin" {
  namespace = data.vault_namespace.cluster_ns.path
  backend = "kubernetes-admin-${var.cluster_id}"
  name    = "${var.team_name}-${var.app_namespace}"

  service_account_name          = var.sa_name
  allowed_kubernetes_namespaces = [var.app_namespace]

  token_default_ttl       = 21600
  token_max_ttl           = 43200
}