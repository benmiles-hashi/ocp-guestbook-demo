resource "vault_policy" "kv_infra" {
  #namespace = var.vault_namespace
  name      = "openshift-rosa-kv-read-infra-${module.rosa_hcp.cluster_id}"

  policy = <<EOT
path "openshift-rosa-${module.rosa_hcp.cluster_id}/*" {
  capabilities = ["read", "list"]
}
EOT
}
resource "vault_policy" "aap_vault_write" {
  #namespace = var.vault_namespace
  name      = "openshift-rosa-kv-write-${module.rosa_hcp.cluster_id}"

  policy = <<EOT
path "openshift-rosa-${module.rosa_hcp.cluster_id}/*" {
  capabilities = ["read", "list", "create"]
}
EOT
}
resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle-aap"
}

resource "vault_approle_auth_backend_role" "aap_controller" {
  backend        = vault_auth_backend.approle.path
  role_name      = "aap-controller"
  token_policies = [
    vault_policy.kv_infra.name
  ]

  token_ttl     = 3600    # 1 hour
  token_max_ttl = 14400   # 4 hours
}

data "vault_approle_auth_backend_role_id" "aap_controller" {
  backend  = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.aap_controller.role_name
}

resource "vault_approle_auth_backend_role_secret_id" "aap_controller" {
  backend  = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.aap_controller.role_name
}

######################################
# Outputs
######################################
output "aap_vault_role_id" {
  value     = data.vault_approle_auth_backend_role_id.aap_controller.role_id
  sensitive = true
}

output "aap_vault_secret_id" {
  value     = vault_approle_auth_backend_role_secret_id.aap_controller.secret_id
  sensitive = true
}
