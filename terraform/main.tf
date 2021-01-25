provider "aws" {
  region = "eu-west-1"
}

locals {
  cluster_name = "my-eks-cluster"
  cluster_version = "1.18"
}

module "vpc" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-vpc?ref=v2.66.0"

  name = "my-vpc"

  cidr = "10.255.0.0/16"

  azs              = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets  = ["10.255.0.0/24", "10.255.1.0/24", "10.255.2.0/24"]
  private_subnet_tags = {
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"                      = "1"
    }
  public_subnets   = ["10.255.10.0/24", "10.255.11.0/24", "10.255.12.0/24"]
  public_subnet_tags = {
      "kubernetes.io/cluster/${local.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                      = "1"
    }

  enable_nat_gateway = true
  single_nat_gateway = true
  one_nat_gateway_per_az = false

  enable_vpn_gateway = false

  enable_dns_hostnames = true

  tags = {
    Terraformed = "True"
    Name        = "my-vpc"
    Environment  = "dev"
  }
}

module "eks" {
  source       = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v13.2.0"
  cluster_name = local.cluster_name
  cluster_version = local.cluster_version
  vpc_id       = module.vpc.vpc_id
  subnets      = module.vpc.public_subnets
  enable_irsa = true

  node_groups = {
    eks_nodes = {
      desired_capacity = 3
      max_capacity     = 3
      min_capaicty     = 3

      instance_type = "t2.small"
    }
  }
  manage_aws_auth = false
}
