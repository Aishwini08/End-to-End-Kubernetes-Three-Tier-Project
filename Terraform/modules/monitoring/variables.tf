variable "grafana_admin_password" {
  description = "Admin password for Grafana dashboard"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack Incoming Webhook URL for AlertManager notifications"
  type        = string
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel name for alerts"
  type        = string
  default     = "#all-k8s-alerts"
}