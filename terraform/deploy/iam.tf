resource "aws_iam_role" "pod_identity" {
  for_each = local.pod_identity_role_names

  name               = "${var.name}-${each.key}-pod-identity-role"
  assume_role_policy = local.pod_identity_trust_policy

  tags = {
    Name      = "${var.name}-${each.key}-pod-identity-role"
    Component = each.key
  }
}

resource "aws_iam_role" "ec2_node" {
  for_each = local.ec2_role_names

  name = each.value
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
    Name      = each.value
    Component = each.key
  }
}

resource "aws_iam_role_policy_attachment" "eks_node" {
  for_each = local.eks_node_policy_arns

  role       = aws_iam_role.ec2_node["eks_node"].name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = local.eks_node_policy_arns

  role       = aws_iam_role.ec2_node["karpenter_node"].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = local.ec2_role_names["karpenter_node_instance_profile"]
  role = aws_iam_role.ec2_node["karpenter_node"].name

  tags = {
    Name = local.ec2_role_names["karpenter_node_instance_profile"]
  }
}

resource "aws_iam_role" "controller_installer" {
  name = "${var.name}-controller-installer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.jump_server.arn
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.name}-controller-installer-role"
  }
}

resource "aws_iam_role_policy" "controller_installer" {
  name = "${var.name}-controller-installer"
  role = aws_iam_role.controller_installer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["eks:DescribeCluster"]
      Resource = aws_eks_cluster.main.arn
    }]
  })
}