variable "aws_region" {
  description = "AWS region in which to deploy the voting app."
  type        = string
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