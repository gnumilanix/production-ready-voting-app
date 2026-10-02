variable "aws_region" {
  description = "AWS region in which to deploy the voting app infrastructure."
  type        = string
}

variable "grafana_region" {
  description = "AWS region for IAM Identity Center and Amazon Managed Grafana. Must match the active SSO instance region (us-east-1)."
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "production-ready-voting-app"
      ManagedBy   = "Terraform"
      Environment = "dev"
    }
  }
}

provider "aws" {
  alias  = "grafana"
  region = var.grafana_region

  default_tags {
    tags = {
      Project     = "production-ready-voting-app"
      ManagedBy   = "Terraform"
      Environment = "dev"
    }
  }
}