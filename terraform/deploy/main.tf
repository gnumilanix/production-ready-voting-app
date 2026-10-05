module "vpc" {
  source = "../modules/vpc"

  name     = var.name
  vpc_cidr = var.vpc_cidr
}

module "jump_server" {
  source = "../modules/jump-server"

  name       = var.name
  vpc_id     = module.vpc.vpc_id
  subnet_id  = module.vpc.public_subnet_ids["0"]
  ssh_cidr   = var.jump_server_ssh_cidr
  public_key = var.jump_server_public_key
}

module "eks" {
  source = "../modules/eks"

  name                          = var.name
  vpc_id                        = module.vpc.vpc_id
  vpc_cidr                      = module.vpc.vpc_cidr
  private_subnet_ids            = module.vpc.private_subnet_ids
  jump_server_role_arn          = module.jump_server.role_arn
  jump_server_security_group_id = module.jump_server.security_group_id
}

module "karpenter" {
  source = "../modules/karpenter"

  name                      = var.name
  cluster_name              = module.eks.cluster_name
  cluster_arn               = module.eks.cluster_arn
  cluster_security_group_id = module.eks.cluster_security_group_id

  depends_on = [module.eks]
}

module "aws_load_balancer_controller" {
  source = "../modules/aws-load-balancer-controller"

  name              = var.name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer       = module.eks.oidc_issuer
}

module "vault" {
  source = "../modules/vault"

  name               = var.name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  cluster_name       = module.eks.cluster_name
  cluster_arn        = module.eks.cluster_arn

  depends_on = [module.eks]
}

module "amp" {
  source = "../modules/amp"

  name         = var.name
  cluster_name = module.eks.cluster_name
  cluster_arn  = module.eks.cluster_arn

  depends_on = [module.eks]
}

module "grafana" {
  source = "../modules/grafana"

  name              = var.name
  amp_workspace_arn = module.amp.workspace_arn

  providers = {
    aws.grafana = aws.grafana
  }
}
