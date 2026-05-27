terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }
}

module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
  region   = var.region
}

module "eks" {
  source = "./modules/eks"

  cluster_name = "three-tier-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets
}

module "addons" {
  source = "./modules/addons"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
}

module "jenkins" {
  source = "./modules/jenkins"

  vpc_id               = module.vpc.vpc_id
  public_subnet_id     = module.vpc.public_subnets[0]
  iam_instance_profile = aws_iam_instance_profile.jenkins.name

  # IAM profile must exist before EC2 is created
  depends_on = [aws_iam_instance_profile.jenkins]
}

# ── ECR Repositories ──────────────────────────────────────────
resource "aws_ecr_repository" "frontend" {
  name                 = "frontend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "backend" {
  name                 = "backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ── IAM role for Jenkins EC2 ──────────────────────────────────
resource "aws_iam_role" "jenkins_ecr_role" {
  name = "jenkins-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Required for docker build/push in Jenkinsfile
resource "aws_iam_role_policy_attachment" "jenkins_ecr" {
  role       = aws_iam_role.jenkins_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# Required for `aws eks update-kubeconfig` which kubectl/helm calls need.
# Without this the Get AWS Account ID / ECR Login stages in Jenkinsfile fail.
resource "aws_iam_role_policy" "jenkins_eks" {
  name = "jenkins-eks-describe"
  role = aws_iam_role.jenkins_ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster", "eks:ListClusters"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "jenkins-ecr-profile"
  role = aws_iam_role.jenkins_ecr_role.name
}

# ── ArgoCD Installation via Helm ──────────────────────────────
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "7.4.0"
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [file("${path.module}/argocd-values.yaml")]

  depends_on = [module.eks]
}

# helm_release completes when pods are scheduled, but the Application
# CRD may not be registered yet. This prevents kubernetes_manifest from
# failing with "no matches for kind Application".
resource "time_sleep" "wait_for_argocd_crds" {
  create_duration = "60s"
  depends_on      = [helm_release.argocd]
}

# ── GitHub credentials for ArgoCD ─────────────────────────────
# NOTE: Terraform state stores these values in plaintext.
# For production, use External Secrets Operator + AWS Secrets Manager.
resource "kubernetes_secret" "github_creds" {
  metadata {
    name      = "github-creds"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    username = var.github_username
    password = var.github_token
    url      = var.github_repo_url
    type     = "git"
  }

  depends_on = [helm_release.argocd]
}

# ── ArgoCD Applications ────────────────────────────────────────
resource "kubernetes_manifest" "argocd_app_frontend" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "frontend"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.github_repo_url
        targetRevision = "main"
        path           = "helm-charts/frontend"
        helm           = { valueFiles = ["values.yaml"] }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "three-tier"
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [time_sleep.wait_for_argocd_crds, kubernetes_secret.github_creds]
}

resource "kubernetes_manifest" "argocd_app_backend" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "backend"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.github_repo_url
        targetRevision = "main"
        path           = "helm-charts/backend"
        helm           = { valueFiles = ["values.yaml"] }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "three-tier"
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [time_sleep.wait_for_argocd_crds, kubernetes_secret.github_creds]
}

resource "kubernetes_manifest" "argocd_app_mongodb" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "mongodb"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.github_repo_url
        targetRevision = "main"
        path           = "helm-charts/mongodb"
        helm           = { valueFiles = ["values.yaml"] }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "three-tier"
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }
  depends_on = [time_sleep.wait_for_argocd_crds, kubernetes_secret.github_creds]
}

# ── Ansible Automation ────────────────────────────────────────
resource "null_resource" "ansible_setup" {
  provisioner "local-exec" {
    command = <<-EOT
      cp ${path.module}/modules/jenkins/jenkins-key.pem ~/.ssh/jenkins-key.pem
      chmod 400 ~/.ssh/jenkins-key.pem

      echo "[jenkins]" > ${path.module}/../Ansible/inventory.ini
      echo "${module.jenkins.jenkins_public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/jenkins-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" \
        >> ${path.module}/../Ansible/inventory.ini

      # Poll SSH instead of fixed sleep
      for i in $(seq 1 30); do
        ssh -o StrictHostKeyChecking=no \
            -o ConnectTimeout=5 \
            -i ~/.ssh/jenkins-key.pem \
            ubuntu@${module.jenkins.jenkins_public_ip} exit 2>/dev/null && break
        echo "Waiting for SSH... attempt $i/30"
        sleep 10
      done

      ansible-playbook \
        -i ${path.module}/../Ansible/inventory.ini \
        ${path.module}/../Ansible/jenkins.yml \
        --vault-password-file ~/vault-pass
    EOT
  }

  depends_on = [module.jenkins]
}

# ── Prometheus + Grafana ──────────────────────────────────────
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "58.2.2"

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "prometheus.prometheusSpec.service.type"
    value = "ClusterIP"
  }

  # Set via: export TF_VAR_grafana_admin_password="yourpassword"
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  depends_on = [module.eks, module.addons]
}