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
          nodePort = 30300  # Access at http://192.168.1.76:30300
        }
        ssh = {
          type = "NodePort"
          port = 22
          nodePort = 30222
        }
      }
      
      gitea = {
        admin = {
          username = "admin"
          password = "changeme"  # Change this!
          email = "admin@gitea.local"
        }
        config = {
          server = {
            DOMAIN = "192.168.1.76"
            ROOT_URL = "http://192.168.1.76:30300/"
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
