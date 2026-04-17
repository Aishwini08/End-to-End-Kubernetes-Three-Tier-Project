variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy the EKS cluster into"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for EKS nodes"
}

variable "cluster_name" {}