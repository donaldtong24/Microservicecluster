# High-Availability Microservice Orchestration on AWS EKS

A professional-grade DevOps project demonstrating the deployment of a containerized Python FastAPI microservice on a managed Kubernetes cluster (Amazon EKS) using Infrastructure as Code (Terraform).

## 🏗️ Architecture
The infrastructure is designed for high availability and security, following AWS best practices:
- **VPC Design:** Custom VPC with Public and Private subnets across two Availability Zones.
- **Compute:** Amazon EKS (v1.30) cluster utilizing Managed Node Groups on Amazon Linux 2023 (AL2023).
- **Networking:** NAT Gateway for secure outbound traffic from private nodes; AWS Elastic Load Balancer (ELB) for public traffic routing.
- **Registry:** Private Amazon ECR for secure container image management.

## 🚀 Key Features
- **Infrastructure as Code:** 100% automated provisioning using Terraform modules.
- **Zero-Downtime Deployments:** Implemented Kubernetes Rolling Updates for seamless application versioning.
- **Self-Healing:** Liveness and readiness probes against `/health`, backing the Rolling Update strategy above.
- **Resource Management:** Kubernetes Resource Requests and Limits set on the container.
- **Templated Multi-Environment Deploys:** Helm chart (`charts/python-microservice`) with `values-dev.yaml` (1 replica, ClusterIP, lower limits) and `values-prod.yaml` (2 replicas, LoadBalancer) — same chart, two environments.
- **Observability:** Prometheus + Grafana via the `kube-prometheus-stack` Helm chart (Terraform-managed, `monitoring.tf`). The app exposes `/metrics` (request counts, latency, Python runtime stats) via `prometheus-fastapi-instrumentator`, scraped through a `ServiceMonitor`. A `PrometheusRule` alerts on OOMKilled containers. CPU/memory dashboards come from kube-prometheus-stack's built-in Grafana dashboards.

## 🛠️ Tech Stack
- **Cloud:** AWS (EKS, ECR, VPC, IAM, ELB)
- **Containerization:** Docker
- **Orchestration:** Kubernetes (kubectl), Helm
- **IaC:** Terraform
- **Backend:** Python (FastAPI, Uvicorn)

## 📋 Project Workflow
1. **Containerization:** Built and optimized a Docker image for a FastAPI microservice.
2. **Registry Management:** Authenticated with AWS ECR and managed image lifecycle versions.
3. **Infrastructure Provisioning:** Utilized Terraform to build the underlying network and EKS control plane.
4. **Deployment:** Authored a Helm chart (`charts/python-microservice`) templating the deployment/service across dev and prod values files; `deployment.yaml` at the repo root remains as a plain-manifest reference, kept in sync with the same resource limits and probes.
5. **Observability:** `terraform apply` provisions `kube-prometheus-stack` (Prometheus, Grafana, Alertmanager, and the Prometheus Operator CRDs) into a dedicated `monitoring` namespace. The app's Helm chart then ships its own `ServiceMonitor` (scrapes `/metrics` every 15s) and `PrometheusRule` (fires `PythonMicroservicePodOOMKilled` on any OOM-killed container), gated behind `monitoring.enabled` so the chart still installs cleanly on a cluster where the operator isn't deployed yet.

## ⎈ Helm Usage

```powershell
# lint
helm lint charts/python-microservice

# render without installing (sanity check)
helm template myrelease charts/python-microservice -f charts/python-microservice/values-dev.yaml

# install/upgrade against a real cluster
helm upgrade --install python-microservice charts/python-microservice -f charts/python-microservice/values-prod.yaml
```

## 📈 Observability Setup

Order matters — the app chart's `ServiceMonitor`/`PrometheusRule` CRDs don't exist until the operator is installed:

```powershell
# 1. Provision Prometheus + Grafana + Alertmanager (Terraform-managed)
terraform apply

# 2. Deploy the app WITH monitoring enabled (values-prod.yaml sets monitoring.enabled: true)
helm upgrade --install python-microservice charts/python-microservice -f charts/python-microservice/values-prod.yaml

# 3. Grafana admin password
terraform output -raw grafana_admin_password

# 4. Reach Grafana locally
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

On dev (`values-dev.yaml`, `monitoring.enabled: false`), the chart installs without the operator being present — useful for quick local iteration.

## 🚧 Challenges Overcome
- **PowerShell Encoding:** Resolved AWS ECR login issues related to PowerShell string piping by implementing `.Trim()` and sub-expression handling.
- **K8s Versioning:** Navigated Kubernetes minor version update constraints (1.29 to 1.30) by performing controlled infrastructure resets.
- **Network Isolation:** Debugged I/O timeouts by enabling public endpoint access while maintaining private subnet integrity for worker nodes.

## 🧹 Cleanup
To avoid unnecessary costs, the environment is fully ephemeral:
```powershell
kubectl delete -f deployment.yaml
terraform destroy