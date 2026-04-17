
module "vpc" {
  source = "./modules/vpc"
   vpc_cidr = var.vpc_cidr
   region   = var.region
}

module "eks" {
  source     = "./modules/eks"

  cluster_name = var.cluster_name
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
}

module "addons" {
  source = "./modules/addons"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
}

module "jenkins" {
  source = "./modules/jenkins"

  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnets[0]
}