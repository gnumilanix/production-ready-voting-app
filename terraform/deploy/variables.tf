variable "name" {
  description = "Prefix used for names and tags on network resources."
  type        = string
  default     = "voting-app"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. Must be a /20 to provide six /24 subnets."
  type        = string
  default     = "10.0.0.0/20"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && try(tonumber(split("/", var.vpc_cidr)[1]) == 20, false)
    error_message = "vpc_cidr must be a valid IPv4 CIDR block with a /20 prefix."
  }
}