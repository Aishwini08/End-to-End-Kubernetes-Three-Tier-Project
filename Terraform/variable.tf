variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "ap-south-1"
}

variable "github_username" {
  type        = string
  description = "GitHub username for ArgoCD repo access"
}

variable "github_token" {
  type        = string
  description = "GitHub personal access token for ArgoCD repo access"
  sensitive   = true
}

variable "github_repo_url" {
  type        = string
  description = "Full HTTPS URL of the GitHub repository"
  default     = "https://github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project.git"
}

# Pass via: export TF_VAR_grafana_admin_password="yourpassword"
# or add grafana_admin_password = "..." in terraform.tfvars
variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password for kube-prometheus-stack"
  sensitive   = true
}