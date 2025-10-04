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
    cluster_id      = "rosa-12345"
    vault_addr      = "https://vault.example.com"
    vault_token     = "s.xxxxxxx"
    vault_namespace = "admin"
    sa_namespace    = "kube-system"
    sa_name         = "tf-admin"
  })
}

resource "aap_job" "vso_operator_install" {
  job_template_id = data.aap_job_template.vso_operator_install.id
  extra_vars = jsonencode({
    cluster_id       = "rosa-12345"
    vault_addr       = "https://vault.example.com"
    vault_token      = "s.xxxxxxx"
    vault_namespace  = "admin"
    vault_mount      = "openshift-rosa-12345"
    sub_namespace    = "openshift-operators"
    operator_package = "vault-secrets-operator"
    operator_channel = "stable"
    catalog_source   = "certified-operators"
    catalog_ns       = "openshift-marketplace"
  })
}

