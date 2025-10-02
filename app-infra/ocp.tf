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
