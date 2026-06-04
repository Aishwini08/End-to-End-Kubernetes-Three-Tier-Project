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
}
