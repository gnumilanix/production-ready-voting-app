resource "aws_security_group" "eks_control_plane" {
  name        = "${var.name}-eks-control-plane"
  description = "Control-plane access from the jump server and VPC Prometheus"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from the jump server"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.jump_server_security_group_id]
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

resource "aws_eks_cluster" "main" {
  name     = var.name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    subnet_ids              = values(var.private_subnet_ids)
    security_group_ids      = [aws_security_group.eks_control_plane.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  tags = {
    Name = "${var.name}-eks"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster]
}

resource "aws_iam_openid_connect_provider" "eks" {
  url            = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "${var.name}-eks-oidc-provider"
  }
}

resource "aws_eks_access_entry" "jump_server" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.jump_server_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jump_server_view" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.jump_server_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  depends_on = [aws_eks_access_entry.jump_server]

  access_scope {
    type = "cluster"
  }
}

resource "aws_iam_role" "eks_console" {
  name = "${var.name}-eks-console-role"

  # Trust policy seeds with the account root so the role is creatable; grant real
  # users/roles console access by adding their ARNs here via the IAM console or CLI.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })

  # Trust-policy principals are managed out-of-band (IAM console/CLI); don't let
  # Terraform revert them on subsequent applies.
  lifecycle {
    ignore_changes = [assume_role_policy]
  }

  tags = {
    Name = "${var.name}-eks-console-role"
  }
}

resource "aws_eks_access_entry" "console_user" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_console.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "console_user_admin_view" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.console_user.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"

  depends_on = [aws_eks_access_entry.console_user]

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "controller_installer" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.controller_installer.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "controller_installer_admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.controller_installer.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  depends_on = [aws_eks_access_entry.controller_installer]

  access_scope {
    type = "cluster"
  }
}
