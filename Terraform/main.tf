
module "vpc" {
  source = "./modules/vpc"
   vpc_cidr = var.vpc_cidr
   region   = var.region
}

module "eks" {
  source = "./modules/eks"

  cluster_name = "three-tier-cluster"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}

module "addons" {
  source = "./modules/addons"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
}

module "jenkins" {
  source = "./modules/jenkins"

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
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

# ── GitHub credentials for ArgoCD to pull your Helm charts ────
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

