output "workspace_id" {
  description = "The Amazon Managed Grafana Workspace ID."
  value       = aws_grafana_workspace.main.id
}

output "workspace_endpoint" {
  description = "Endpoint URL of the AMG Grafana workspace."
  value       = aws_grafana_workspace.main.endpoint
}

output "workspace_arn" {
  description = "ARN of the AMG Grafana workspace."
  value       = aws_grafana_workspace.main.arn
}

output "service_account_id" {
  description = "Service account ID used to provision Grafana resources."
  value       = aws_grafana_workspace_service_account.datasource_provisioner.service_account_id
}

output "grafana_admins_group_id" {
  description = "Identity Center group ID for GrafanaAdmins."
  value       = aws_identitystore_group.grafana_admins.group_id
}

output "workspace_role_arn" {
  description = "IAM role ARN used by the Grafana workspace to query AMP data."
  value       = aws_iam_role.grafana_workspace.arn
}
