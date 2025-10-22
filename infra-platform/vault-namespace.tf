
resource "vault_namespace" "cluster_ns" {
  provider = "admin"
  path = "rosa-${module.rosa_hcp.cluster_id}"
}

# ────────────────────────────────────────────────────────────────────────
# STEP 2: Enable userpass auth inside the namespace
# ────────────────────────────────────────────────────────────────────────
resource "vault_auth_backend" "userpass" {
  provider = "admin"
  namespace = vault_namespace.cluster_ns.path
  type      = "userpass"
  path      = "userpass"
}

# ────────────────────────────────────────────────────────────────────────
# STEP 3: Create an admin policy inside the namespace
# ────────────────────────────────────────────────────────────────────────
resource "vault_policy" "admin_policy" {
  provider = "admin"
  namespace = vault_namespace.cluster_ns.path
  name      = "admin-policy"

  # Full admin rights within the namespace
  policy = <<EOT
# Grant full capabilities on all paths
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

# ────────────────────────────────────────────────────────────────────────
# STEP 4: Generate a random password for the admin user
# ────────────────────────────────────────────────────────────────────────
resource "random_password" "admin_pass" {
  length  = 16
  special = false
}

# ────────────────────────────────────────────────────────────────────────
# STEP 5: Create the userpass admin user and attach the admin policy
# ────────────────────────────────────────────────────────────────────────
resource "vault_generic_endpoint" "admin_user" {
    provider = "admin"
  namespace = vault_namespace.cluster_ns.path
  path      = "auth/${vault_auth_backend.userpass.path}/users/admin"

  data_json = jsonencode({
    password = random_password.admin_pass.result
    policies = [vault_policy.admin_policy.name]
  })
}

# ────────────────────────────────────────────────────────────────────────
# STEP 6: Outputs
# ────────────────────────────────────────────────────────────────────────
output "vault_namespace_path" {
  value = vault_namespace.cluster_ns.path
}

output "vault_admin_username" {
  value = "admin"
}

output "vault_admin_password" {
  value     = random_password.admin_pass.result
  sensitive = true
}

output "vault_admin_policy" {
  value = vault_policy.admin_policy.name
}
