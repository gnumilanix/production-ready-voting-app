variable "name" {
  description = "Prefix used for names and tags on Vault resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the Vault EFS file system."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC, allowed NFS access to the Vault EFS file system."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EFS mount targets, keyed by zero-based subnet index."
  type        = map(string)
}

variable "cluster_name" {
  description = "Name of the EKS cluster running Vault."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster running Vault."
  type        = string
}
