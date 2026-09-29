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