resource "vault_mount" "kv_mount" {
  path          = "openshift-rosa-${var.cluster_id}"
  type          = "kv"
  options       = { version = "2" }
}
ephemeral "vault_kv_secret_v2" "infra" {
  mount = "openshift-rosa-${var.cluster_id}"
  name  = "infra"
  mount_id = vault_mount.kv_mount.id
}