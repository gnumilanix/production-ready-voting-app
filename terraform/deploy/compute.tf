data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_caller_identity" "current" {}

locals {
  eks_oidc_issuer = trimprefix(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://")

  pod_identity_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnEquals = {
          "aws:SourceArn" = aws_eks_cluster.main.arn
        }
      }
    }]
  })

  pod_identity_role_names = toset([
    "adot-container-logs",
    "adot-otlp-ingest",
    "adot-prom-metrics",
    "argocd",
    "ebs-csi",
    "vpc-cni",
    "external-dns",
    "prometheus-exporter",
    "karpenter",
    "vault"
  ])

  eks_addon_names = toset([
    "vpc-cni",
    "coredns",
    "kube-proxy",
    "metrics-server",
    "eks-node-monitoring-agent",
    "aws-ebs-csi-driver",
    "eks-pod-identity-agent"
  ])

  eks_addons_with_pod_identity = {
    "vpc-cni" = {
      role_key        = "vpc-cni"
      service_account = "aws-node"
    }
    "aws-ebs-csi-driver" = {
      role_key        = "ebs-csi"
      service_account = "ebs-csi-controller-sa"
    }
  }

  eks_node_groups = {
    "spot-small-general" = {
      desired_size = 2
      min_size     = 1
      max_size     = 4
      taints       = []
    }
    "spot-small-stateful" = {
      desired_size = 1
      min_size     = 1
      max_size     = 2
      taints = [{
        key    = "workload-type"
        value  = "spot-stateful"
        effect = "PREFER_NO_SCHEDULE"
      }]
    }
  }

  ec2_role_names = {
    eks_node                        = "${var.name}-eks-node-role"
    karpenter_node_instance_profile = "${var.name}-karpenter-node-instance-profile-role"
    karpenter_node                  = "${var.name}-karpenter-node-role"
  }

  eks_node_policy_arns = {
    worker_node = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    cni         = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    ecr_pull    = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  }
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

resource "aws_iam_instance_profile" "jump_server" {
  name = "voting-app-jump-server-profile"
  role = aws_iam_role.jump_server.name

  tags = {
    Name = "${var.name}-jump-server-profile"
  }
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = local.ec2_role_names["karpenter_node_instance_profile"]
  role = aws_iam_role.ec2_node["karpenter_node"].name

  tags = {
    Name = local.ec2_role_names["karpenter_node_instance_profile"]
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

  access_config {
    authentication_mode = "API"
  }

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

resource "aws_ec2_tag" "karpenter_cluster_security_group_discovery" {
  resource_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.name
}

resource "aws_eks_access_entry" "jump_server" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.jump_server.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "jump_server_view" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.jump_server.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  depends_on = [aws_eks_access_entry.jump_server]

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_policy_association" "jump_server_admin_view" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.jump_server.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminViewPolicy"

  depends_on = [aws_eks_access_entry.jump_server]

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "console_user" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.eks_console_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.ec2_node["karpenter_node"].arn
  type          = "EC2_LINUX"
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

resource "aws_eks_node_group" "spot" {
  for_each = local.eks_node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.ec2_node["eks_node"].arn
  subnet_ids      = [for subnet in values(aws_subnet.private) : subnet.id]

  capacity_type  = "SPOT"
  instance_types = ["t3.small"]

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = {
    Name = "${var.name}-${each.key}"
  }

  depends_on = [aws_iam_role_policy_attachment.eks_node]
}

data "aws_eks_addon_version" "managed" {
  for_each = local.eks_addon_names

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.pod_identity["vpc-cni"].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.pod_identity["ebs-csi"].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}

resource "aws_eks_addon" "managed" {
  for_each = setsubtract(
    local.eks_addon_names,
    setunion(toset(keys(local.eks_addons_with_pod_identity)), toset(["coredns"]))
  )

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = each.key
  addon_version = data.aws_eks_addon_version.managed[each.key].version

  tags = {
    Name = "${var.name}-${each.key}"
  }

}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.managed["coredns"].version

  tags = {
    Name = "${var.name}-coredns"
  }

  depends_on = [aws_eks_node_group.spot["spot-small-stateful"]]
}

resource "aws_eks_addon" "with_pod_identity" {
  for_each = local.eks_addons_with_pod_identity

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = each.key
  addon_version               = data.aws_eks_addon_version.managed[each.key].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  configuration_values = each.key == "vpc-cni" ? jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  }) : null

  pod_identity_association {
    role_arn        = aws_iam_role.pod_identity[each.value.role_key].arn
    service_account = each.value.service_account
  }

  tags = {
    Name = "${var.name}-${each.key}"
  }

  depends_on = [
    aws_eks_addon.managed["eks-pod-identity-agent"],
    aws_iam_role_policy_attachment.vpc_cni,
    aws_iam_role_policy_attachment.ebs_csi
  ]
}

resource "aws_eks_pod_identity_association" "argocd_application_controller" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "argocd"
  service_account = "argocd-application-controller"
  role_arn        = aws_iam_role.pod_identity["argocd"].arn

  depends_on = [aws_eks_addon.managed["eks-pod-identity-agent"]]
}

resource "aws_eks_pod_identity_association" "argocd_image_updater" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "argocd"
  service_account = "argocd-image-updater"
  role_arn        = aws_iam_role.pod_identity["argocd"].arn

  depends_on = [aws_eks_addon.managed["eks-pod-identity-agent"]]
}

resource "aws_eks_pod_identity_association" "argo_rollouts" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "argocd"
  service_account = "argo-rollouts"
  role_arn        = aws_iam_role.pod_identity["argocd"].arn

  depends_on = [aws_eks_addon.managed["eks-pod-identity-agent"]]
}

resource "aws_eks_pod_identity_association" "karpenter" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "karpenter"
  service_account = "karpenter"
  role_arn        = aws_iam_role.pod_identity["karpenter"].arn

  depends_on = [aws_eks_addon.managed["eks-pod-identity-agent"]]
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.name}-karpenter-controller-policy"
  description = "Permissions for the Karpenter controller on the ${var.name} EKS cluster."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KarpenterControllerEC2Operations"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeCapacityReservations",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribePlacementGroups",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Sid      = "KarpenterControllerPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.ec2_node["karpenter_node"].arn
        Condition = {
          StringEquals = {
            "iam:PassedToService" = ["ec2.amazonaws.com", "ec2.amazonaws.com.cn"]
          }
        }
      },
      {
        Sid      = "KarpenterControllerEKSDescribe"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = aws_eks_cluster.main.arn
      },
      {
        Sid      = "KarpenterControllerPricing"
        Effect   = "Allow"
        Action   = "pricing:GetProducts"
        Resource = "*"
      },
      {
        Sid      = "KarpenterControllerIAMInstanceProfileList"
        Effect   = "Allow"
        Action   = "iam:ListInstanceProfiles"
        Resource = "*"
      },
      {
        Sid    = "KarpenterControllerIAMInstanceProfileManagement"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.pod_identity["karpenter"].name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

resource "aws_eks_pod_identity_association" "vault" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "vault"
  service_account = "vault"
  role_arn        = aws_iam_role.pod_identity["vault"].arn

  depends_on = [aws_eks_addon.managed["eks-pod-identity-agent"]]
}

resource "aws_iam_openid_connect_provider" "eks" {
  url            = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]

  tags = {
    Name = "${var.name}-eks-oidc-provider"
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.name}-aws-load-balancer-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.eks_oidc_issuer}:aud" = "sts.amazonaws.com"
          "${local.eks_oidc_issuer}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })

  tags = {
    Name      = "${var.name}-aws-load-balancer-controller-role"
    Component = "aws-load-balancer-controller"
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.name}-aws-load-balancer-controller-policy"
  description = "Permissions for the AWS Load Balancer Controller on the ${var.name} EKS cluster."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "ec2:GetSecurityGroupsForVpc",
          "ec2:DescribeIpamPools",
          "ec2:DescribeRouteTables",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTrustStores",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:DescribeCapacityReservation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "acm:ListCertificates",
          "acm:DescribeCertificate",
          "iam:ListServerCertificates",
          "iam:GetServerCertificate",
          "waf-regional:GetWebACL",
          "waf-regional:GetWebACLForResource",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL",
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL",
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateSecurityGroup"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "arn:aws:ec2:*:*:security-group/*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteRule"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster"  = "true"
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags"
        ]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
          "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:ModifyListenerAttributes",
          "elasticloadbalancing:ModifyCapacityReservation",
          "elasticloadbalancing:ModifyIpPools"
        ]
        Resource = "*"
        Condition = {
          Null = {
            "aws:ResourceTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = ["elasticloadbalancing:AddTags"]
        Resource = [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
        Condition = {
          StringEquals = {
            "elasticloadbalancing:CreateAction" = [
              "CreateTargetGroup",
              "CreateLoadBalancer"
            ]
          }
          Null = {
            "aws:RequestTag/elbv2.k8s.aws/cluster" = "false"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets"
        ]
        Resource = "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:SetRulePriorities"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
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
