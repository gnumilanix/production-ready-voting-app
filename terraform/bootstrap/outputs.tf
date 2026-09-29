output "state_bucket_name" {
  description = "S3 bucket used to store Terraform state."
  value       = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  description = "KMS key used to encrypt Terraform state."
  value       = aws_kms_key.state.arn
}

output "aws_account_id" {
  description = "AWS account in which the backend resources were created."
  value       = data.aws_caller_identity.current.account_id
}