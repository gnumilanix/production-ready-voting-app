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

resource "aws_iam_role" "eks_cluster" {
  name = "voting-app-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = {
    Name = "${var.name}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
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

resource "aws_instance" "jump_server" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public["0"].id
  vpc_security_group_ids      = [aws_security_group.jump_server.id]
  key_name                    = aws_key_pair.jump_server.key_name
  iam_instance_profile        = aws_iam_instance_profile.jump_server.name
  associate_public_ip_address = true
  user_data = templatefile("${path.module}/scripts/jumpserver_bootstrap.sh", {
    cluster_name = var.name
  })

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

resource "aws_eks_cluster" "main" {
  name     = var.name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.33"

  vpc_config {
    subnet_ids              = [for subnet in values(aws_subnet.private) : subnet.id]
    security_group_ids      = [aws_security_group.eks_control_plane.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  tags = {
    Name = "${var.name}-eks"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}