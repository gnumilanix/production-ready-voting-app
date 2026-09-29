provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "production-ready-voting-app"
      ManagedBy   = "Terraform"
      Environment = "bootstrap"
    }
  }
}