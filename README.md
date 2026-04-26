# End-to-End Kubernetes Three-Tier Project

A fully automated CI/CD pipeline that deploys a three-tier web application (Frontend + Backend + MongoDB) on AWS EKS using GitOps principles.

---

## Architecture Overview

```
Developer → GitHub → Jenkins → AWS ECR
                         ↓
                    ArgoCD (GitOps)
                         ↓
                    AWS EKS Cluster
                    ├── Frontend (React)
                    ├── Backend (Node.js)
                    └── MongoDB (StatefulSet + EBS)
                         ↓
                  Prometheus + Grafana (Monitoring)
```

---

## Tech Stack

| Category | Tool | Purpose |
|---|---|---|
| Infrastructure | Terraform | Provision AWS resources |
| Configuration | Ansible | Configure Jenkins server |
| CI | Jenkins | Build, scan, push images |
| Code Quality | SonarQube | Static code analysis |
| Security | OWASP | Dependency vulnerability scan |
| Security | Trivy | Docker image scan |
| Registry | AWS ECR | Private image registry |
| CD | ArgoCD | GitOps deployment |
| Orchestration | AWS EKS | Managed Kubernetes |
| Packaging | Helm | Kubernetes package manager |
| Database | MongoDB | NoSQL database |
| Monitoring | Prometheus | Metrics collection |
| Monitoring | Grafana | Metrics visualization |

---

## Project Structure

```
End-to-End-EKS-Three-Tier-Project/
│
├── Terraform/                          # Infrastructure as Code
│   ├── modules/
│   │   ├── vpc/                        # VPC, subnets, IGW
│   │   ├── eks/                        # EKS cluster + worker nodes
│   │   ├── jenkins/                    # Jenkins EC2 + security group
│   │   └── addons/                     # EKS addons (CoreDNS, EBS-CSI etc.)
│   ├── main.tf                         # Root module + ArgoCD + Prometheus
│   ├── provider.tf                     # AWS, Helm, Kubernetes providers
│   ├── variables.tf                    # Input variables
│   ├── outputs.tf                      # Outputs (URLs, passwords)
│   ├── terraform.tfvars                # Variable values
│   └── argocd-values.yaml              # ArgoCD Helm config
│
├── Ansible/                            # Server configuration
│   ├── jenkins.yml                     # Installs Jenkins, Docker, kubectl, Helm, AWS CLI, SonarQube, OWASP
│   └── inventory.ini                   # Jenkins EC2 IP + SSH key
│
├── helm-charts/                        # Kubernetes app packaging
│   ├── frontend/                       # React frontend chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml                 # image.tag updated by Jenkins
│   │   └── templates/
│   ├── backend/                        # Node.js backend chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml                 # image.tag updated by Jenkins
│   │   └── templates/
│   └── mongodb/                        # MongoDB StatefulSet chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│
├── Application-Code/                   # App source code
│   ├── frontend/                       # React app + Dockerfile
│   └── backend/                        # Node.js app + Dockerfile
│
├── storageclass.yaml                   # gp2-immediate StorageClass for MongoDB
└── Jenkinsfile                         # CI pipeline definition
```

---

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Ansible (via WSL on Windows)
- Git

---

## Setup & Deployment

### Step 1 — Set GitHub Token
```bash
# Windows CMD
set TF_VAR_github_token=ghp_xxxxxxxxxxxxxxxxxxxx

# Linux/Mac
export TF_VAR_github_token=ghp_xxxxxxxxxxxxxxxxxxxx
```

### Step 2 — Terraform Stage 1 (Infrastructure)
```bash
cd Terraform/

terraform init

terraform apply \
  -target=module.vpc \
  -target=module.eks \
  -target=module.addons \
  -target=module.jenkins \
  -target=aws_ecr_repository.frontend \
  -target=aws_ecr_repository.backend \
  -target=aws_iam_instance_profile.jenkins
```
⏱️ Takes 10-15 minutes

### Step 3 — Terraform Stage 2 (ArgoCD + Monitoring)
```bash
terraform apply \
  -target=helm_release.argocd \
  -target=kubernetes_secret.github_creds \
  -target=helm_release.prometheus
```

### Step 4 — Terraform Final Apply (ArgoCD Apps)
```bash
terraform apply
```

Note down outputs:
```
jenkins_url           = http://x.x.x.x:8080
argocd_url            = http://xxx.elb.amazonaws.com
grafana_url           = http://xxx.elb.amazonaws.com
argocd_admin_password = <run: terraform output argocd_admin_password>
```

### Step 5 — Update kubeconfig
```bash
aws eks update-kubeconfig --region ap-south-1 --name three-tier-cluster
```

### Step 6 — Apply StorageClass for MongoDB
```bash
kubectl apply -f storageclass.yaml
```

### Step 7 — Configure Ansible Inventory
Update `Ansible/inventory.ini` with Jenkins IP:
```ini
[jenkins]
<jenkins-public-ip> ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/jenkins-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

### Step 8 — Run Ansible
```bash
# Copy SSH key (WSL)
cp Terraform/modules/jenkins/jenkins-key.pem ~/.ssh/jenkins-key.pem
chmod 400 ~/.ssh/jenkins-key.pem

cd Ansible/
ansible-playbook -i inventory.ini jenkins.yml
```
⏱️ Takes 5-10 minutes

### Step 9 — Fix ArgoCD GitHub Token
```bash
kubectl create secret generic github-creds \
  --from-literal=username=Aishwini08 \
  --from-literal=password=ghp_xxxxxxxxxxxxxxxxxxxx \
  --from-literal=url=https://github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project.git \
  --from-literal=type=git \
  -n argocd \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment argocd-server -n argocd
```

### Step 10 — Configure Jenkins

1. Open `http://<jenkins-ip>:8080`
2. Get initial password:
   ```bash
   ssh -i ~/.ssh/jenkins-key.pem ubuntu@<jenkins-ip> \
   "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
   ```
3. Install suggested plugins
4. Add credentials:
   - `github-credentials` — GitHub username + PAT token
   - `sonarqube-token` — SonarQube token (from step 11)
5. Create pipeline job → SCM → Jenkinsfile
6. Add GitHub webhook: `http://<jenkins-ip>:8080/github-webhook/`

### Step 11 — Configure SonarQube

1. Open `http://<jenkins-ip>:9000`
2. Login: `admin / admin` → change password
3. Create project: `three-tier-app`
4. Generate token → copy it
5. Add to Jenkins as `sonarqube-token` credential

---

## Jenkins Pipeline Stages

```
Stage 1:  Checkout              → Pull code from GitHub
Stage 2:  OWASP Dependency Check → Scan npm packages for CVEs
Stage 3:  SonarQube Analysis    → Static code quality analysis
Stage 4:  Get AWS Account ID    → For ECR URL construction
Stage 5:  ECR Login             → Authenticate via IAM role
Stage 6:  Build & Push Frontend → Docker build + push to ECR
Stage 7:  Build & Push Backend  → Docker build + push to ECR
Stage 8:  Trivy Image Scan      → Scan images for vulnerabilities
Stage 9:  Update Helm Tags      → Update image tags in values.yaml
Stage 10: Push to GitHub        → Commit [skip ci] + push
```

---

## CI/CD Flow

```
git push
    ↓
GitHub Webhook → Jenkins
    ↓
Build + Scan + Push to ECR
    ↓
Update Helm chart values.yaml
    ↓
Push to GitHub [skip ci]
    ↓
ArgoCD detects change
    ↓
Rolling update on EKS
    ↓
Zero downtime deployment ✅
```

---

## Accessing Services

| Service | URL | Credentials |
|---|---|---|
| Frontend App | `kubectl get svc -n three-tier` | - |
| Jenkins | `http://<jenkins-ip>:8080` | admin / your password |
| ArgoCD | terraform output argocd_url | admin / terraform output argocd_admin_password |
| Grafana | terraform output grafana_url | admin / admin123 |
| SonarQube | `http://<jenkins-ip>:9000` | admin / your password |

---

## Monitoring

Import these Grafana dashboards:
```
15760 → Kubernetes cluster overview
6417  → Kubernetes pod metrics
1860  → Node metrics
```

---

## Verify Everything is Running

```bash
# Check application pods
kubectl get pods -n three-tier

# Check monitoring
kubectl get pods -n monitoring

# Check ArgoCD apps
kubectl get applications -n argocd

# Check services
kubectl get svc -n three-tier
```

Expected output:
```
three-tier:
  frontend   1/1   Running  ✅
  backend    1/1   Running  ✅
  mongodb    1/1   Running  ✅

ArgoCD:
  frontend   Synced   Healthy  ✅
  backend    Synced   Healthy  ✅
  mongodb    Synced   Healthy  ✅
```

---

## Safe Destroy (Avoid AWS Charges)

```bash
# Delete LoadBalancer services first
kubectl delete svc -n three-tier --all
kubectl delete svc argocd-server -n argocd
kubectl delete svc prometheus-grafana -n monitoring

# Wait 2 minutes for ELBs to be removed from AWS

# Destroy all infrastructure
terraform destroy
```

---

## Common Issues & Fixes

| Problem | Fix |
|---|---|
| ArgoCD shows Unknown | Update github-creds secret with new token |
| MongoDB PVC Pending | `kubectl apply -f storageclass.yaml` |
| Jenkins docker permission denied | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins` |
| Jenkins infinite build loop | Add `[skip ci]` to commit message |
| terraform destroy fails | Delete LoadBalancer services first |
| No space left on device | `docker system prune -af` on Jenkins EC2 |
| ECR ImagePullBackOff | Run Jenkins pipeline to build and push images |

---

## Key Configuration

```
AWS Region:        ap-south-1
EKS Cluster:       three-tier-cluster
Kubernetes:        v1.31
Worker Nodes:      2x t3.large
Jenkins EC2:       t3.large (30GB disk)
MongoDB Storage:   1Gi EBS gp2-immediate
Namespaces:        three-tier, argocd, monitoring
ArgoCD Sync:       every 3 minutes
```

---

## Author

**Aishwini08** — [GitHub](https://github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project)
