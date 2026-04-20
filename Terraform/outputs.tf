output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "jenkins_url" {
  value = module.jenkins.jenkins_url
}

# ── ArgoCD outputs ─────────────────────────────────────────────
data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
  depends_on = [helm_release.argocd]
}

data "kubernetes_secret" "argocd_admin_password" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }
  depends_on = [helm_release.argocd]
}

output "argocd_url" {
  value       = "http://${data.kubernetes_service.argocd_server.status[0].load_balancer[0].ingress[0].hostname}"
  description = "ArgoCD UI URL"
}

output "argocd_admin_password" {
  value       = data.kubernetes_secret.argocd_admin_password.data["password"]
  sensitive   = true
  description = "ArgoCD initial admin password"
}