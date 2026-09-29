variable "aws_region" {
  description = "AWS region in which to create the Terraform state resources."
  type        = string
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string

  validation {
    condition     = length(var.state_bucket_name) >= 3 && length(var.state_bucket_name) <= 63
    error_message = "The state bucket name must be between 3 and 63 characters."
  }
}
