ephemeral "vault_kv_secret_v2" "infra" {
  mount = "openshift-rosa-${var.cluster_id}"
  name  = "infra"
}