module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.project_name}-${var.environment}"
  cidr = var.vpc_cidr

  azs              = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets   = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  private_subnets  = [cidrsubnet(var.vpc_cidr, 4, 2), cidrsubnet(var.vpc_cidr, 4, 3)]
  database_subnets = [cidrsubnet(var.vpc_cidr, 4, 4), cidrsubnet(var.vpc_cidr, 4, 5)]

  enable_nat_gateway   = true
  single_nat_gateway   = true # cost tradeoff for early stage; switch to one-per-AZ before production traffic
  enable_dns_hostnames = true

  create_database_subnet_group = true
}
