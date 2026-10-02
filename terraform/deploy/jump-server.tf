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

resource "aws_iam_role_policy" "jump_server_eks_management" {
  name = "${var.name}-jump-server-eks-management"
  role = aws_iam_role.jump_server.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeControllerInstallerRole"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = aws_iam_role.controller_installer.arn
      },
      {
        Sid    = "EKSManagement"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeClusterVersions",
          "eks:DescribeNodegroup",
          "eks:UpdateNodegroupVersion",
          "eks:DescribeUpdate",
          "eks:ListUpdates",
          "eks:DescribeAddon"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["eks:CreatePodIdentityAssociation"]
        Resource = aws_eks_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          aws_iam_role.pod_identity["argocd"].arn,
          aws_iam_role.pod_identity["karpenter"].arn,
          aws_iam_role.pod_identity["vault"].arn
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "pods.eks.amazonaws.com"
          }
        }
      },
      {
        Sid    = "AllowEKSUpdateTracking"
        Effect = "Allow"
        Action = [
          "eks:DescribeUpdate",
          "eks:ListUpdates"
        ]
        Resource = [
          aws_eks_cluster.main.arn,
          format("arn:aws:eks:%s:%s:nodegroup/%s/*", var.aws_region, data.aws_caller_identity.current.account_id, aws_eks_cluster.main.name),
          format("arn:aws:eks:%s:%s:nodegroup/%s/*/*", var.aws_region, data.aws_caller_identity.current.account_id, aws_eks_cluster.main.name)
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:AttachRolePolicy"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:ListOpenIDConnectProviders",
          "iam:GetOpenIDConnectProvider",
          "iam:CreateOpenIDConnectProvider",
          "iam:GetRole",
          "iam:TagRole"
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowOIDCTagging"
        Effect   = "Allow"
        Action   = ["iam:TagOpenIDConnectProvider"]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/*"
      },
      {
        Sid      = "AllowEKSTagging"
        Effect   = "Allow"
        Action   = ["eks:TagResource"]
        Resource = aws_eks_cluster.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "codecommit:GitPull",
          "codecommit:Get*",
          "codecommit:BatchGet*",
          "codecommit:List*"
        ]
        Resource = "arn:aws:codecommit:${var.aws_region}:${data.aws_caller_identity.current.account_id}:playground"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudformation:ListStacks",
          "cloudformation:DescribeStacks",
          "cloudformation:GetTemplate",
          "cloudformation:UpdateStack",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStackResources"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2AndAutoscalingForNodegroup"
        Effect = "Allow"
        Action = [
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeScheduledActions",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "jump_server_vault_initialization" {
  name = "${var.name}-jump-server-vault-initialization"
  role = aws_iam_role.jump_server.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue"
      ]
      Resource = aws_secretsmanager_secret.vault_initialization.arn
    }]
  })
}