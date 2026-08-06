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
- **Persistence:** RDS Postgres (`database.tf`), private-subnet only, security group locked to the EKS node security group. `GET /visits` reads/writes a real counter row — not just a provisioned-and-unused database.

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

## 🗄️ Database Setup

`database.tf` provisions RDS Postgres and a Kubernetes Secret with the connection string; `values-prod.yaml` wires that secret into the app as `DATABASE_URL`. Locally, without `DATABASE_URL` set, `/visits` returns `{"error": "DATABASE_URL not configured"}` instead of crashing — verified end-to-end against a real local Postgres instance (table auto-created on startup, `/visits` incrementing 1 → 2 → 3 across repeated calls).

```powershell
# 1. Provision RDS (part of the same terraform apply as monitoring.tf)
terraform apply

# 2. Deploy the app — values-prod.yaml already points DATABASE_URL at the
#    Secret database.tf creates
helm upgrade --install python-microservice charts/python-microservice -f charts/python-microservice/values-prod.yaml

# 3. Test it
curl http://<load-balancer-hostname>/visits
```

## 🦊 GitLab CI (parallel pipeline)

`.gitlab-ci.yml` runs the same app through a second CI/CD path, alongside the existing GitHub Actions workflow — build/push to ECR, `helm lint` + `helm template` as a gate, then `helm upgrade --install` using `values-prod.yaml` with the freshly built image tag. Requires these CI/CD variables in the GitLab project: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, `ECR_REPOSITORY`, `EKS_CLUSTER_NAME`.

## 🚧 Challenges Overcome
- **PowerShell Encoding:** Resolved AWS ECR login issues related to PowerShell string piping by implementing `.Trim()` and sub-expression handling.
- **K8s Versioning:** Navigated Kubernetes minor version update constraints (1.29 to 1.30) by performing controlled infrastructure resets.
- **Network Isolation:** Debugged I/O timeouts by enabling public endpoint access while maintaining private subnet integrity for worker nodes.

## 🧹 Cleanup
To avoid unnecessary costs, the environment is fully ephemeral. Delete the Helm release *before* the infrastructure — `terraform destroy` doesn't know about the AWS resources Kubernetes provisions on its own (see gotchas below):
```powershell
helm uninstall python-microservice
terraform destroy
```

### ⚠️ Teardown gotchas
If the Helm release isn't uninstalled first (or a prior teardown got interrupted), `terraform destroy` will fail partway through with `DependencyViolation` errors on the VPC's subnets/internet gateway. Cause: `values-prod.yaml`'s `Service type: LoadBalancer` makes Kubernetes' AWS cloud provider create a Classic ELB (and a security group for it) directly against the AWS API — entirely outside Terraform's state. If the EKS cluster gets destroyed first, both are orphaned and sit in the VPC blocking its deletion.

Manual fix if this happens:
```powershell
# Find and delete the orphaned ELB
aws elb describe-load-balancers --region us-east-1
aws elb delete-load-balancer --load-balancer-name <name> --region us-east-1

# Find and delete the security group it created (named k8s-elb-<lb-name>)
aws ec2 describe-security-groups --region us-east-1 --filters "Name=vpc-id,Values=<vpc-id>"
aws ec2 delete-security-group --group-id <sg-id> --region us-east-1

# Then re-run
terraform destroy
```

Separately, `terraform destroy` also refuses to delete the ECR repo while it still holds images, since `force_delete` isn't set on `aws_ecr_repository.my_app` in `main.tf`:
```powershell
aws ecr batch-delete-image --repository-name my-python-service --region us-east-1 --image-ids imageTag=<tag>
```