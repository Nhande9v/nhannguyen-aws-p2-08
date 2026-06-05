resource "kubernetes_deployment" "web_app" {
  metadata {
    name = "production-web-app"
    labels = {
      app = "nginx-web"
    }
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "nginx-web"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx-web"
        }
      }
      spec {
        container {
          name  = "nginx-core"
          image = "nginx:alpine"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}