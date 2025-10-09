
resource "vault_token" "aap_job_token" {
  policies = ["openshift-rosa-kv-write-${module.rosa_hcp.cluster_id}"]
  ttl      = "1h"
  renewable = false
}
data "aap_job_template" "tf_admin_sa" {
  name              = "OCP - TF Admin SA Setup"
  organization_name = "Default"
}

data "aap_job_template" "vso_operator_install" {
  name              = "OCP - VSO Operator Install"
  organization_name = "Default"
}
data "aap_job_template" "vault_credential" {
  name              = "OCP - Vault Credential Setup"
  organization_name = "Default"
}

resource "aap_job" "vault_credential" {
  job_template_id = data.aap_job_template.vault_credential.id
  extra_vars = jsonencode({
    vault_addr            = var.vault_address
    vault_namespace       = "admin"
    controller_host       = var.aap_hostname
    controller_username   = var.aap_username
    controller_password   = var.aap_password
    vault_role_id         = data.vault_approle_auth_backend_role_id.aap_controller.role_id
    vault_secret_id       = vault_approle_auth_backend_role_secret_id.aap_controller.secret_id
  })
  wait_for_completion = true
}

resource "aap_job" "tf_admin_sa" {
  job_template_id = data.aap_job_template.tf_admin_sa.id
  extra_vars = jsonencode({
    cluster_id      = module.rosa_hcp.cluster_id
    vault_addr      = var.vault_address
    vault_token     = vault_token.aap_job_token.client_token
    vault_namespace = "admin"
    sa_namespace    = "kube-system"
    sa_name         = "tf-admin"
  })
  wait_for_completion = true
  depends_on = [ aap_job.vault_credential ]
}

data "vault_kv_secret_v2" "ocp" {
  mount = "openshift-rosa-${module.rosa_hcp.cluster_id}"
  name  = "ocp"
  depends_on = [ aap_job.tf_admin_sa ]
}
