data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_iam_role" "jump_server" {
  name = "voting-app-jump-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.name}-jump-server-role"
  }
}

resource "aws_iam_instance_profile" "jump_server" {
  name = "voting-app-jump-server-profile"
  role = aws_iam_role.jump_server.name

  tags = {
    Name = "${var.name}-jump-server-profile"
  }
}

resource "aws_key_pair" "jump_server" {
  key_name   = "${var.name}-jump-server"
  public_key = var.jump_server_public_key

  tags = {
    Name = "${var.name}-jump-server"
  }
}

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

resource "aws_instance" "jump_server" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public["0"].id
  vpc_security_group_ids      = [aws_security_group.jump_server.id]
  key_name                    = aws_key_pair.jump_server.key_name
  iam_instance_profile        = aws_iam_instance_profile.jump_server.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name}-jump-server"
  }
}