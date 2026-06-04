output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "jenkins_url" {
  value = module.jenkins.jenkins_url
}

output "ecr_frontend_url" {
  value = module.ecr.frontend_repo_url
}

output "ecr_backend_url" {
  value = module.ecr.backend_repo_url
}
