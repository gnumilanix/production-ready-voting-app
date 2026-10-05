variable "name" {
  description = "Prefix used for names and tags on Grafana resources."
  type        = string
}

variable "amp_workspace_arn" {
  description = "ARN of the AMP workspace the Grafana workspace queries."
  type        = string
}
