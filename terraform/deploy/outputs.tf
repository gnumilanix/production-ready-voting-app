output "vpc_id" {
  description = "ID of the application VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the VPC."
  value       = module.vpc.vpc_cidr
}

output "availability_zones" {
  description = "Three availability zones hosting the application subnets."
  value       = module.vpc.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs, keyed by zero-based subnet index."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs, keyed by zero-based subnet index."
  value       = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the VPC internet gateway."
  value       = module.vpc.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "ID of the shared NAT gateway."
  value       = module.vpc.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "Public IP address of the shared NAT gateway."
  value       = module.vpc.nat_gateway_public_ips
}

output "jump_server_instance_id" {
  description = "ID of the public jump server instance."
  value       = module.jump_server.instance_id
}

output "jump_server_public_ip" {
  description = "Public IP address of the jump server."
  value       = module.jump_server.public_ip
}

output "jump_server_key_pair_name" {
  description = "EC2 key pair name used by the jump server."
  value       = module.jump_server.key_pair_name
}

output "jump_server_security_group_id" {
  description = "Security group ID attached to the jump server."
  value       = module.jump_server.security_group_id
}

output "eks_control_plane_security_group_id" {
  description = "Security group ID for the EKS control plane."
  value       = module.eks.control_plane_security_group_id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_region" {
  description = "AWS region hosting the EKS cluster."
  value       = var.aws_region
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "eks_cluster_endpoint" {
  description = "Private Kubernetes API endpoint for the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN assumed by the AWS Load Balancer Controller service account."
  value       = module.aws_load_balancer_controller.role_arn
}

output "controller_installer_role_arn" {
  description = "IAM role assumed by the jump server to install the AWS Load Balancer Controller."
  value       = module.eks.controller_installer_role_arn
}

output "eks_console_role_arn" {
  description = "IAM role users assume to get read-only EKS console access."
  value       = module.eks.eks_console_role_arn
}

output "vault_efs_file_system_id" {
  description = "EFS file system ID backing the Vault data volume."
  value       = module.vault.efs_file_system_id
}

output "amp_remote_write_url" {
  description = "Remote-write endpoint of the AMP workspace for the Prometheus agent."
  value       = module.amp.remote_write_url
}

output "grafana_workspace_endpoint" {
  description = "Endpoint URL of the AMG Grafana workspace."
  value       = module.grafana.workspace_endpoint
}

output "amg_workspace_id" {
  value       = module.grafana.workspace_id
  description = "The Amazon Managed Grafana Workspace ID"
}

output "amg_service_account_id" {
  value       = module.grafana.service_account_id
  description = "Service account ID used to provision Grafana resources"
}

output "grafana_admins_group_id" {
  description = "Identity Center group ID for GrafanaAdmins."
  value       = module.grafana.grafana_admins_group_id
}

output "grafana_workspace_role_arn" {
  value       = module.grafana.workspace_role_arn
  description = "IAM role ARN used by the Grafana workspace to query AMP data"
}

output "amp_workspace_id" {
  value       = module.amp.workspace_id
  description = "The Amazon Managed Prometheus Workspace ID"
}

output "amp_region" {
  value       = var.aws_region
  description = "Region containing the AMP workspace"
}