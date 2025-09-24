# Define ArgoCD project
resource "argocd_project" "microservices" {
  metadata {
    name      = "microservices"
    namespace = "argocd"
  }

  spec {
    description = "Microservices project"
    
    source_repos = [
      "https://gitlab.example.com/team/services/*",
      "https://github.com/argoproj/argocd-example-apps"
    ]

    destination {
      server    = "https://kubernetes.default.svc"
      namespace = "microservices-*"
    }

    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }

    namespace_resource_whitelist {
      group = "*"
      kind  = "*"
    }

    role {
      name = "admin"
      policies = [
        "p, proj:microservices:admin, applications, *, microservices/*, allow",
        "p, proj:microservices:admin, repositories, *, *, allow"
      ]
      groups = ["platform-team"]
    }
  }
}

# Repository credentials (using AWS Secrets Manager reference)
resource "argocd_repository_credentials" "private_gitlab" {
  url      = "https://gitlab.example.com/team"
  username = "argocd"
  password = data.aws_secretsmanager_secret_version.gitlab_token.secret_string
}