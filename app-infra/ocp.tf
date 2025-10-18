resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
}

resource "kubernetes_service_account" "app_sa" {
  metadata {
    name      = var.sa_name
    namespace = kubernetes_namespace.app.metadata[0].name
  }
}

resource "kubernetes_role_binding" "app_admin_binding" {
  metadata {
    name      = "${var.sa_name}-admin"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.app_sa.metadata[0].name
    namespace = kubernetes_namespace.app.metadata[0].name
  }
}

