output "vpc_id" {
  description = "ID of the application VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "IPv4 CIDR block assigned to the VPC."
  value       = aws_vpc.main.cidr_block
}

output "availability_zones" {
  description = "Three availability zones hosting the application subnets."
  value       = local.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs, keyed by zero-based subnet index."
  value       = { for index, subnet in aws_subnet.public : index => subnet.id }
}

output "private_subnet_ids" {
  description = "Private subnet IDs, keyed by zero-based subnet index."
  value       = { for index, subnet in aws_subnet.private : index => subnet.id }
}

output "internet_gateway_id" {
  description = "ID of the VPC internet gateway."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "ID of the shared NAT gateway."
  value       = aws_nat_gateway.main.id
}

output "nat_gateway_public_ips" {
  description = "Public IP address of the shared NAT gateway."
  value       = aws_eip.nat.public_ip
}

output "jump_server_instance_id" {
  description = "ID of the public jump server instance."
  value       = aws_instance.jump_server.id
}

output "jump_server_public_ip" {
  description = "Public IP address of the jump server."
  value       = aws_instance.jump_server.public_ip
}

output "jump_server_key_pair_name" {
  description = "EC2 key pair name used by the jump server."
  value       = aws_key_pair.jump_server.key_name
}

output "jump_server_security_group_id" {
  description = "Security group ID attached to the jump server."
  value       = aws_security_group.jump_server.id
}