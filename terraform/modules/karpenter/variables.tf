variable "name" {
  description = "Prefix used for names and tags on Karpenter resources."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster Karpenter manages."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster Karpenter manages."
  type        = string
}

variable "cluster_security_group_id" {
  description = "Cluster security group ID created by EKS, tagged for Karpenter discovery."
  type        = string
}
