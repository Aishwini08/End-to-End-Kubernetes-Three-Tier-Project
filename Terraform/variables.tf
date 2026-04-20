# ── AWS / EKS ──────────────────────────────────────────────────
variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "three-tier-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# ── ArgoCD / GitHub ────────────────────────────────────────────
variable "github_repo_url" {
  description = "GitHub repository URL for ArgoCD to pull Helm charts"
  type        = string
  default     = ""
}

variable "github_username" {
  description = "GitHub username for ArgoCD repository access"
  type        = string
  default     = ""
}

variable "github_token" {
  description = "GitHub personal access token (pass via TF_VAR_github_token env var)"
  type        = string
  sensitive   = true
  default     = ""
}