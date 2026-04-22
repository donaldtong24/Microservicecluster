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
- **Self-Healing:** Configured Liveness Probes and ReplicaSets to ensure high service availability.
- **Resource Management:** Optimized costs and performance using Kubernetes Resource Requests and Limits.

## 🛠️ Tech Stack
- **Cloud:** AWS (EKS, ECR, VPC, IAM, ELB)
- **Containerization:** Docker
- **Orchestration:** Kubernetes (kubectl)
- **IaC:** Terraform
- **Backend:** Python (FastAPI, Uvicorn)

## 📋 Project Workflow
1. **Containerization:** Built and optimized a Docker image for a FastAPI microservice.
2. **Registry Management:** Authenticated with AWS ECR and managed image lifecycle versions.
3. **Infrastructure Provisioning:** Utilized Terraform to build the underlying network and EKS control plane.
4. **Deployment:** Authored K8s manifests for deployments and load balancer services.
5. **Observability (Planned):** Integration of Prometheus and Grafana for cluster-wide monitoring.

## 🚧 Challenges Overcome
- **PowerShell Encoding:** Resolved AWS ECR login issues related to PowerShell string piping by implementing `.Trim()` and sub-expression handling.
- **K8s Versioning:** Navigated Kubernetes minor version update constraints (1.29 to 1.30) by performing controlled infrastructure resets.
- **Network Isolation:** Debugged I/O timeouts by enabling public endpoint access while maintaining private subnet integrity for worker nodes.

## 🧹 Cleanup
To avoid unnecessary costs, the environment is fully ephemeral:
```powershell
kubectl delete -f deployment.yaml
terraform destroy