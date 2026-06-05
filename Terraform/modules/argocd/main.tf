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
}

resource "time_sleep" "wait_for_argocd_crds" {
  create_duration = "120s"
  depends_on      = [helm_release.argocd]
}

# ── GitHub Credentials for ArgoCD ─────────────────────────────
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