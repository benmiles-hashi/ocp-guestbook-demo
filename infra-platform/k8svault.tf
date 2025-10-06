
locals {
  reviewer_jwt = data.vault_kv_secret_v2.ocp.data["token"]
  api_ca_pem  = try(data.vault_kv_secret_v2.ocp.data["ca_cert"], "")
  mount_path = "openshift-rosa-${module.rosa_hcp.cluster_id}"
}


resource "vault_kubernetes_secret_backend" "config" {

  path                = "kubernetes-admin-${module.rosa_hcp.cluster_id}"
  description         = "Kubernetes SA token factory for ROSA cluster ${module.rosa_hcp.cluster_id}"
  kubernetes_host     = module.rosa_hcp.cluster_api_url
  kubernetes_ca_cert  = local.api_ca_pem
  service_account_jwt = local.reviewer_jwt
  depends_on = [ aap_job.tf_admin_sa ]
}

resource "vault_kubernetes_secret_backend_role" "terraform_admin" {
  backend = vault_kubernetes_secret_backend.config.path
  name    = "terraform-admin"

  service_account_name          = "${var.sa_name_prefix}-${module.rosa_hcp.cluster_id}"
  allowed_kubernetes_namespaces = [var.sa_namespace]

  token_default_ttl       = 21600
  token_max_ttl           = 43200
}

resource "vault_kv_secret_v2" "vault_meta" {
  mount = local.mount_path
  name  = "vault"

  data_json = jsonencode({
    k8s_engine_path = vault_kubernetes_secret_backend.config.path
    k8s_role        = vault_kubernetes_secret_backend_role.terraform_admin.name
  })
}

output "k8s_sa_engine_path" {
  value = vault_kubernetes_secret_backend.config.path
}

output "k8s_sa_role_name" {
  value = vault_kubernetes_secret_backend_role.terraform_admin.name
}

output "k8s_sa_subject" {
  value = "system:serviceaccount:${var.sa_namespace}:${var.sa_name_prefix}-${module.rosa_hcp.cluster_id}"
}
