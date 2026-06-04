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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# ── Networking ────────────────────────────────────────────────
module "vpc" {
  source   = "./modules/vpc"
  vpc_cidr = var.vpc_cidr
  region   = var.region
}

# ── EKS Cluster ───────────────────────────────────────────────
module "eks" {
  source       = "./modules/eks"
  cluster_name = "three-tier-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnets
}

# ── EKS Addons (EBS CSI, ALB Controller, etc.) ────────────────
module "addons" {
  source            = "./modules/addons"
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
}

# ── ECR + IAM for Jenkins ─────────────────────────────────────
module "ecr" {
  source = "./modules/ecr"
}

# ── Jenkins EC2 ───────────────────────────────────────────────
module "jenkins" {
  source               = "./modules/jenkins"
  vpc_id               = module.vpc.vpc_id
  public_subnet_id     = module.vpc.public_subnets[0]
  iam_instance_profile = module.ecr.iam_instance_profile

  depends_on = [module.ecr]
}

# ── StorageClass for MongoDB ──────────────────────────────────
resource "null_resource" "update_kubeconfig" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name three-tier-cluster"
  }
}

resource "null_resource" "apply_storageclass" {
  depends_on = [null_resource.update_kubeconfig]

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/../helm-charts/storageclass.yaml"
  }
}

# ── Ansible: Configure Jenkins ────────────────────────────────
resource "null_resource" "ansible_setup" {
  depends_on = [module.jenkins]

  provisioner "local-exec" {
    command = <<-EOT
      cp ${path.module}/modules/jenkins/jenkins-key.pem ~/.ssh/jenkins-key.pem
      chmod 400 ~/.ssh/jenkins-key.pem

      echo "[jenkins]" > ${path.module}/../Ansible/inventory.ini
      echo "${module.jenkins.jenkins_public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/jenkins-key.pem ansible_ssh_common_args='-o StrictHostKeyChecking=no'" \
        >> ${path.module}/../Ansible/inventory.ini

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
        ${path.module}/../Ansible/jenkins.yml
    EOT
  }
}

# ── ArgoCD Install + GitHub Creds ────────────────────────────
module "argocd" {
  source          = "./modules/argocd"
  github_username = var.github_username
  github_token    = var.github_token
  github_repo_url = var.github_repo_url

  depends_on = [module.eks, module.addons]
}

# ── ArgoCD Applications (requires CRDs from above) ───────────
module "argocd_apps" {
  source          = "./modules/argocd_apps"
  github_repo_url = var.github_repo_url

  depends_on = [module.argocd]
}

# ── Monitoring: Prometheus + Grafana ─────────────────────────
module "monitoring" {
  source                 = "./modules/monitoring"
  grafana_admin_password = var.grafana_admin_password

  depends_on = [module.eks, module.addons]
}