
resource "vault_token" "aap_job_token" {
  policies = ["openshift-rosa-kv-write-${module.rosa_hcp.cluster_id}"]
  ttl      = "5m"
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
}

data "vault_kv_secret_v2" "ocp" {
  mount = "openshift-rosa-${module.rosa_hcp.cluster_id}"
  name  = "ocp"
  depends_on = [ aap_job.tf_admin_sa ]
}
