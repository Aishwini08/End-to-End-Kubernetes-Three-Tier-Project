variable "vpc_id" {}
variable "public_subnet_id" {}
variable "iam_instance_profile" {
  description = "IAM instance profile for Jenkins EC2"
  type        = string
}