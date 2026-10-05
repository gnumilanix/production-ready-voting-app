variable "name" {
  description = "Prefix used for names and tags on AMP resources."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster running the Prometheus agent."
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the EKS cluster running the Prometheus agent."
  type        = string
}
