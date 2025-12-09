# App of Apps pattern for self-managed ArgoCD
resource "argocd_application" "bootstrap" {
  metadata {
    name      = "bootstrap"
    namespace = "argocd"
  }

  spec {
    project = "default"

    source {
      repo_url        = "https://gitlab.example.com/platform/argocd-bootstrap"
      path            = "applications"
      target_revision = "main"
    }

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "argocd"
    }

    sync_policy {
      automated {
        prune     = true
        self_heal = true
      }
    }
  }
}