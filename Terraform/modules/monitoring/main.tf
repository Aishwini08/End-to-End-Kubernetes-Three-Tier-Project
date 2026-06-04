# ── Prometheus + Grafana via Helm ─────────────────────────────
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

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}