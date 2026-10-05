output "role_arn" {
  description = "IAM role ARN assumed by the AWS Load Balancer Controller service account."
  value       = aws_iam_role.aws_load_balancer_controller.arn
}
