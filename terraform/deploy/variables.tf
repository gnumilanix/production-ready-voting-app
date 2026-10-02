variable "name" {
  description = "Prefix used for names and tags on network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. Must be a /20 to provide six /24 subnets."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && try(tonumber(split("/", var.vpc_cidr)[1]) == 20, false)
    error_message = "vpc_cidr must be a valid IPv4 CIDR block with a /20 prefix."
  }
}

variable "jump_server_ssh_cidr" {
  description = "IPv4 CIDR allowed to SSH to the jump server. Do not use 0.0.0.0/0."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.jump_server_ssh_cidr)) && try(tonumber(split("/", var.jump_server_ssh_cidr)[1]) >= 0, false)
    error_message = "jump_server_ssh_cidr must be a valid IPv4 CIDR narrower than 0.0.0.0/0."
  }
}

variable "jump_server_public_key" {
  description = "OpenSSH public key installed on the jump server."
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-[A-Za-z0-9-]+) ", var.jump_server_public_key))
    error_message = "jump_server_public_key must be an OpenSSH RSA, Ed25519, or ECDSA public key."
  }
}
