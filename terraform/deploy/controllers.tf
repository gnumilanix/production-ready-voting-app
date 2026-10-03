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

resource "aws_kms_key" "vault_unseal" {
  description             = "Vault auto-unseal key for ${var.name}."
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = {
    Name = "${var.name}-vault-unseal"
  }

}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/${var.name}-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

resource "aws_secretsmanager_secret" "vault_initialization" {
  name                    = "${var.name}/vault/init"
  description             = "Vault initialization recovery material for ${var.name}."
  recovery_window_in_days = 0

  tags = {
    Name = "${var.name}-vault-initialization"
  }
}

resource "aws_iam_role_policy" "vault_kms_unseal" {
  name = "${var.name}-vault-kms-unseal"
  role = aws_iam_role.pod_identity["vault"].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt"
      ]
      Resource = aws_kms_key.vault_unseal.arn
    }]
  })
}

resource "aws_eks_pod_identity_association" "vault" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "vault"
  service_account = "vault"
  role_arn        = aws_iam_role.pod_identity["vault"].arn

  depends_on = [
    aws_eks_addon.managed["eks-pod-identity-agent"],
    aws_iam_role_policy.vault_kms_unseal
  ]
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

  policy = file("${path.module}/aws-load-balancer-controller-policy.json")
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}