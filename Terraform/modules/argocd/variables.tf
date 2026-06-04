variable "github_username" {
  description = "GitHub username for ArgoCD repo access"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token for ArgoCD repo access"
  type        = string
  sensitive   = true
}

variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
}
