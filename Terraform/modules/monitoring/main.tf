# ── Prometheus + Grafana + AlertManager via Helm ──────────────
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

  # ── AlertManager: Slack Notifications ────────────────────────
  values = [
    <<-EOT
    alertmanager:
      enabled: true
      config:
        global:
          resolve_timeout: 5m
        route:
          group_by: ['alertname', 'namespace']
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 12h
          receiver: slack-alerts
          routes:
            - matchers:
                - alertname = "Watchdog"
              receiver: 'null'
        receivers:
          - name: 'null'
          - name: slack-alerts
            slack_configs:
              - api_url: '${var.slack_webhook_url}'
                channel: '${var.slack_channel}'
                send_resolved: true
                title: '{{ if eq .Status "firing" }}🔥 FIRING{{ else }}✅ RESOLVED{{ end }}: {{ .CommonLabels.alertname }}'
                text: |-
                  {{ range .Alerts }}
                  *Namespace:* {{ .Labels.namespace }}
                  *Pod:* {{ .Labels.pod }}
                  *Summary:* {{ .Annotations.summary }}
                  *Description:* {{ .Annotations.description }}
                  {{ end }}

    # ── Alert Rules ───────────────────────────────────────────
    additionalPrometheusRulesMap:
      three-tier-alerts:
        groups:
          - name: pod-alerts
            rules:
              - alert: PodCrashLooping
                expr: rate(kube_pod_container_status_restarts_total{namespace="three-tier"}[5m]) * 300 > 1
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "Pod {{ $labels.pod }} is crash looping"
                  description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} has restarted more than 1 time in 5 minutes."

              - alert: PodNotRunning
                expr: kube_pod_status_phase{namespace="three-tier", phase!="Running", phase!="Succeeded"} == 1
                for: 2m
                labels:
                  severity: warning
                annotations:
                  summary: "Pod {{ $labels.pod }} is not running"
                  description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is in {{ $labels.phase }} state."

          - name: node-alerts
            rules:
              - alert: NodeDown
                expr: up{job="node-exporter"} == 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "Node {{ $labels.instance }} is down"
                  description: "Node {{ $labels.instance }} has been unreachable for more than 1 minute."

              - alert: NodeHighCPU
                expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: "High CPU on node {{ $labels.instance }}"
                  description: "Node {{ $labels.instance }} CPU usage is above 80% for 5 minutes."

              - alert: NodeHighMemory
                expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
                for: 5m
                labels:
                  severity: warning
                annotations:
                  summary: "High Memory on node {{ $labels.instance }}"
                  description: "Node {{ $labels.instance }} memory usage is above 80% for 5 minutes."

          - name: mongodb-alerts
            rules:
              - alert: MongoDBDown
                expr: mongodb_up == 0
                for: 1m
                labels:
                  severity: critical
                annotations:
                  summary: "MongoDB is down"
                  description: "MongoDB exporter cannot connect to MongoDB in namespace three-tier."

    # ── MongoDB Exporter ServiceMonitor ──────────────────────
    prometheus:
      prometheusSpec:
        serviceMonitorSelectorNilUsesHelmValues: false
        podMonitorSelectorNilUsesHelmValues: false
    EOT
  ]
}

# ── MongoDB Exporter Deployment ───────────────────────────────
resource "helm_release" "mongodb_exporter" {
  name             = "mongodb-exporter"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-mongodb-exporter"
  namespace        = "three-tier"
  create_namespace = true
  version          = "3.6.0"

  set {
    name  = "mongodb.uri"
    value = "mongodb://admin:password123@mongodb.three-tier.svc.cluster.local:27017/admin"
  }

  set {
    name  = "serviceMonitor.enabled"
    value = "true"
  }

  set {
    name  = "serviceMonitor.namespace"
    value = "monitoring"
  }

  set {
    name  = "serviceMonitor.additionalLabels.release"
    value = "prometheus"
  }

  depends_on = [helm_release.prometheus]
}