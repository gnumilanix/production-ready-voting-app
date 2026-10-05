variable "name" {
  description = "Prefix used for names and tags on jump server resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to deploy the jump server."
  type        = string
}

variable "subnet_id" {
  description = "ID of the public subnet in which to deploy the jump server."
  type        = string
}

variable "ssh_cidr" {
  description = "IPv4 CIDR allowed to SSH to the jump server. Do not use 0.0.0.0/0."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.ssh_cidr)) && try(tonumber(split("/", var.ssh_cidr)[1]) >= 0, false)
    error_message = "ssh_cidr must be a valid IPv4 CIDR narrower than 0.0.0.0/0."
  }
}

variable "public_key" {
  description = "OpenSSH public key installed on the jump server."
  type        = string

  validation {
    condition     = can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-[A-Za-z0-9-]+) ", var.public_key))
    error_message = "public_key must be an OpenSSH RSA, Ed25519, or ECDSA public key."
  }
}
