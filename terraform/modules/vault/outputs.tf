output "efs_file_system_id" {
  description = "EFS file system ID backing the Vault data volume."
  value       = aws_efs_file_system.vault.id
}

output "initialization_secret_arn" {
  description = "ARN of the Secrets Manager secret holding Vault initialization material."
  value       = aws_secretsmanager_secret.vault_initialization.arn
}

output "unseal_kms_key_arn" {
  description = "ARN of the KMS key used for Vault auto-unseal."
  value       = aws_kms_key.vault_unseal.arn
}

output "pod_identity_role_arn" {
  description = "ARN of the Vault pod identity IAM role."
  value       = aws_iam_role.pod_identity.arn
}
