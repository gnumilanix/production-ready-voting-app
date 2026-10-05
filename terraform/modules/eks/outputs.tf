output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Private Kubernetes API endpoint for the EKS cluster."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Cluster security group ID created by EKS for the cluster."
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "control_plane_security_group_id" {
  description = "Security group ID for the EKS control plane."
  value       = aws_security_group.eks_control_plane.id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the EKS cluster."
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer" {
  description = "OIDC issuer URL of the EKS cluster, without the https:// prefix."
  value       = trimprefix(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")
}

output "controller_installer_role_arn" {
  description = "IAM role assumed by the jump server to install cluster controllers."
  value       = aws_iam_role.controller_installer.arn
}

output "eks_console_role_arn" {
  description = "IAM role users assume to get read-only EKS console access."
  value       = aws_iam_role.eks_console.arn
}

output "pod_identity_role_arns" {
  description = "ARNs of the pod identity IAM roles, keyed by component."
  value       = { for key, role in aws_iam_role.pod_identity : key => role.arn }
}
