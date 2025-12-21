terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

provider "kubernetes" {
  config_path = "/etc/rancher/k3s/k3s.yaml"
}

provider "helm" {
  kubernetes {
    config_path = "/etc/rancher/k3s/k3s.yaml"
  }
}

# Create namespace
resource "kubernetes_namespace" "gitea" {
  metadata {
    name = "gitea"
  }
}

# Create secrets from sops-decrypted files
resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.gitea.metadata[0].name
  }

  data = {
    username = "admin"
    password = file("/run/secrets/postgres-password")
  }
}

resource "kubernetes_secret" "gitea_admin" {
  metadata {
    name      = "gitea-admin-secret"
    namespace = kubernetes_namespace.gitea.metadata[0].name
  }

  data = {
    password = file("/run/secrets/gitea-admin-password")
  }
}

# Deploy Gitea via Helm
resource "helm_release" "gitea" {
  name       = "gitea"
  repository = "https://dl.gitea.com/charts/"
  chart      = "gitea"
  namespace  = kubernetes_namespace.gitea.metadata[0].name

  values = [
    yamlencode({
      service = {
        http = {
          type = "NodePort"
          port = 3000
          nodePort = var.gitea_http_port
        }
        ssh = {
          type = "NodePort"
          port = 22
          nodePort = var.gitea_ssh_port
        }
      }
      
      gitea = {
        admin = {
          existingSecret = kubernetes_secret.gitea_admin.metadata[0].name
        }
        config = {
          server = {
            DOMAIN = var.host_ip
            ROOT_URL = "http://${var.host_ip}:${var.gitea_http_port}/"
          }
          database = {
            DB_TYPE = "postgres"
            HOST = "gitea-postgresql:5432"
            NAME = "gitea"
            USER = "gitea"
            PASSWD = kubernetes_secret.postgres.data.password
          }
        }
      }

      persistence = {
        enabled = true
        size = "10Gi"
      }

      postgresql = {
        enabled = true
        persistence = {
          size = "1Gi"
        }
      }

      postgresql-ha = {
        enabled = false
      }
    })
  ]
}
