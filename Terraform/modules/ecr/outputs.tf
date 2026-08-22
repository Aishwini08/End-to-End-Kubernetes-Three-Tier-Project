output "frontend_repo_url" {
  description = "ECR URL for frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_repo_url" {
  description = "ECR URL for backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "iam_instance_profile" {
  description = "IAM instance profile name for Jenkins EC2"
  value       = aws_iam_instance_profile.jenkins.name
}