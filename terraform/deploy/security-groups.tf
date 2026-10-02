resource "aws_security_group" "jump_server" {
  name        = "${var.name}-jump-server"
  description = "SSH access to the jump server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from the configured trusted CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.jump_server_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-jump-server"
  }
}

resource "aws_security_group" "eks_control_plane" {
  name        = "${var.name}-eks-control-plane"
  description = "Control-plane access from the jump server and VPC Prometheus"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS from the jump server"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.jump_server.id]
  }

  ingress {
    description = "Prometheus metrics from the VPC"
    from_port   = 9100
    to_port     = 9100
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
    Name = "${var.name}-eks-control-plane"
  }
}