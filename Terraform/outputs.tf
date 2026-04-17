output "cluster_name" {
  value = module.eks.cluster_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "jenkins_url" {
  value = module.jenkins.jenkins_url
}