variable "name" {
  description = "Prefix used for names and tags on AWS Load Balancer Controller resources."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the EKS cluster."
  type        = string
}

variable "oidc_issuer" {
  description = "OIDC issuer URL of the EKS cluster, without the https:// prefix."
  type        = string
}
