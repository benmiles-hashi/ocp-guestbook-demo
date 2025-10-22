
resource "vault_token" "aap_job_token" {
  policies = ["openshift-rosa-kv-write-${var.cluster_id}"]
  ttl      = "5m"
  renewable = false
}

data "aap_job_template" "vso_operator_install" {
  name              = "OCP - VSO Operator Install"
  organization_name = "Default"
}

resource "aap_job" "vso_install" {
  job_template_id = data.aap_job_template.vso_operator_install.id
  extra_vars = jsonencode({
    cluster_id      = var.cluster_id
    vault_addr      = var.vault_address
    vault_token     = vault_token.aap_job_token.client_token
    vault_namespace = "admin"
    sa_namespace    = "kube-system"
    sa_name         = "tf-admin"
  })
  wait_for_completion = true
}

ephemeral "vault_kv_secret_v2" "config" {
  mount = "openshift-rosa-${var.cluster_id}"
  name  = "config"
  mount_id = vault_mount.kv_mount.id
  depends_on = [ aap_job.vso_install ]
}
