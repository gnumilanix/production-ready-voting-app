variable "name" {
  description = "Prefix used for names and tags on EKS resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to deploy the EKS cluster."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC, used for control-plane security group rules."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EKS cluster and node groups, keyed by zero-based subnet index."
  type        = map(string)
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.33"
}

variable "jump_server_role_arn" {
  description = "ARN of the jump server IAM role, granted cluster admin access."
  type        = string
}

variable "jump_server_security_group_id" {
  description = "Security group ID of the jump server, allowed HTTPS access to the control plane."
  type        = string
}
