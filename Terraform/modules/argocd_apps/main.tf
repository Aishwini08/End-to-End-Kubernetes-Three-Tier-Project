resource "null_resource" "argocd_apps" {
  triggers = {
    repo_url = var.github_repo_url
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<EOF
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: frontend
        namespace: argocd
        finalizers: ["resources-finalizer.argocd.argoproj.io"]
      spec:
        project: default
        source:
          repoURL: ${var.github_repo_url}
          targetRevision: main
          path: helm-charts/frontend
          helm:
            valueFiles: [values.yaml]
        destination:
          server: https://kubernetes.default.svc
          namespace: three-tier
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions: [CreateNamespace=true]
      ---
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: backend
        namespace: argocd
        finalizers: ["resources-finalizer.argocd.argoproj.io"]
      spec:
        project: default
        source:
          repoURL: ${var.github_repo_url}
          targetRevision: main
          path: helm-charts/backend
          helm:
            valueFiles: [values.yaml]
        destination:
          server: https://kubernetes.default.svc
          namespace: three-tier
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions: [CreateNamespace=true]
      ---
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: mongodb
        namespace: argocd
        finalizers: ["resources-finalizer.argocd.argoproj.io"]
      spec:
        project: default
        source:
          repoURL: ${var.github_repo_url}
          targetRevision: main
          path: helm-charts/mongodb
          helm:
            valueFiles: [values.yaml]
        destination:
          server: https://kubernetes.default.svc
          namespace: three-tier
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions: [CreateNamespace=true]
      EOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete application frontend backend mongodb -n argocd --ignore-not-found || true"
  }
}
