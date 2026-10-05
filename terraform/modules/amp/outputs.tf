output "workspace_id" {
  description = "The Amazon Managed Prometheus Workspace ID."
  value       = aws_prometheus_workspace.main.id
}

output "workspace_arn" {
  description = "ARN of the AMP workspace."
  value       = aws_prometheus_workspace.main.arn
}

output "remote_write_url" {
  description = "Remote-write endpoint of the AMP workspace for the Prometheus agent."
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
}

output "pod_identity_role_arn" {
  description = "ARN of the Prometheus exporter pod identity IAM role."
  value       = aws_iam_role.pod_identity.arn
}
