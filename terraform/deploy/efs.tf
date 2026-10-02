resource "aws_security_group" "efs" {
  name        = "${var.name}-efs"
  description = "NFS access to the Vault EFS file system from cluster nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "NFS from within the VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-efs"
  }
}

resource "aws_efs_file_system" "vault" {
  encrypted = true

  tags = {
    Name = "${var.name}-vault"
  }
}

resource "aws_efs_mount_target" "vault" {
  for_each = aws_subnet.private

  file_system_id  = aws_efs_file_system.vault.id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.efs.id]
}
