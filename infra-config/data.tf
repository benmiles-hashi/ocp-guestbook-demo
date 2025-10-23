data "vault_namespace" "cluster_ns"{
    path = "rosa-${var.cluster_id}"
}