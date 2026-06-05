resource "kubernetes_service" "web_app_svc" {
  metadata {
    name = "production-web-service"
  }
  spec {
    selector = {
      app = "nginx-web"
    }
    type = "NodePort"
    port {
      port        = 80
      target_port = 80
      node_port   = 30080
    }
  }
}