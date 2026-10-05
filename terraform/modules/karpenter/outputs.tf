output "pod_identity_role_arn" {
  description = "ARN of the Karpenter controller pod identity IAM role."
  value       = aws_iam_role.pod_identity.arn
}

output "node_role_arn" {
  description = "ARN of the IAM role used by Karpenter-provisioned nodes."
  value       = aws_iam_role.node.arn
}

output "node_instance_profile_name" {
  description = "Name of the instance profile used by Karpenter-provisioned nodes."
  value       = aws_iam_instance_profile.node.name
}
