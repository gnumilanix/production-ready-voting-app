output "instance_id" {
  description = "ID of the public jump server instance."
  value       = aws_instance.jump_server.id
}

output "public_ip" {
  description = "Public IP address of the jump server."
  value       = aws_instance.jump_server.public_ip
}

output "key_pair_name" {
  description = "EC2 key pair name used by the jump server."
  value       = aws_key_pair.jump_server.key_name
}

output "security_group_id" {
  description = "Security group ID attached to the jump server."
  value       = aws_security_group.jump_server.id
}

output "role_arn" {
  description = "ARN of the IAM role attached to the jump server instance profile."
  value       = aws_iam_role.jump_server.arn
}

output "role_name" {
  description = "Name of the IAM role attached to the jump server instance profile."
  value       = aws_iam_role.jump_server.name
}
