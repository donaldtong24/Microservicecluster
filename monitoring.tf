terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Auth against the EKS cluster provisioned in main.tf — reuses the same
# module outputs instead of a separate aws eks update-kubeconfig step.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Grafana admin password, generated instead of hardcoded — read it with:
#   terraform output -raw grafana_admin_password
resource "random_password" "grafana_admin" {
  length  = 20
  special = false
}

# Community chart bundling Prometheus + Grafana + Alertmanager + the
# Prometheus Operator (which provides the ServiceMonitor/PrometheusRule
# CRDs consumed by charts/python-microservice).
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "65.5.1"

  # Let ServiceMonitor/PrometheusRule objects outside the chart's own
  # release (i.e. the ones shipped in charts/python-microservice) be
  # picked up automatically, instead of requiring matching Helm labels.
  values = [
    yamlencode({
      grafana = {
        adminPassword = random_password.grafana_admin.result
      }
      prometheus = {
        prometheusSpec = {
          serviceMonitorSelectorNilUsesHelmValues = false
          ruleSelectorNilUsesHelmValues           = false
        }
      }
    })
  ]
}

output "grafana_admin_password" {
  value     = random_password.grafana_admin.result
  sensitive = true
}
