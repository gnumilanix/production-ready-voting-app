# Cross-module IAM policies for the jump server. These live at the root because
# they reference resources owned by several modules (eks, karpenter, vault,
# grafana); putting them in any single module would create a module dependency
# cycle.
data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "jump_server_eks_management" {
  name = "${var.name}-jump-server-eks-management"
  role = module.jump_server.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeControllerInstallerRole"
        Effect   = "Allow"
        Action   = ["sts:AssumeRole"]
        Resource = module.eks.controller_installer_role_arn
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
        Resource = module.eks.cluster_arn
      },
      {
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          module.eks.pod_identity_role_arns["argocd"],
          module.karpenter.pod_identity_role_arn,
          module.vault.pod_identity_role_arn
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
          module.eks.cluster_arn,
          format("arn:aws:eks:%s:%s:nodegroup/%s/*", var.aws_region, data.aws_caller_identity.current.account_id, module.eks.cluster_name),
          format("arn:aws:eks:%s:%s:nodegroup/%s/*/*", var.aws_region, data.aws_caller_identity.current.account_id, module.eks.cluster_name)
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
        Resource = module.eks.cluster_arn
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
      },
      {
        Sid      = "AllowELBDescribe"
        Effect   = "Allow"
        Action   = ["elbv2:DescribeLoadBalancers"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "jump_server_vault_initialization" {
  name = "${var.name}-jump-server-vault-initialization"
  role = module.jump_server.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue",
        "secretsmanager:PutSecretValue"
      ]
      Resource = module.vault.initialization_secret_arn
    }]
  })
}

resource "aws_iam_role_policy" "jump_server_grafana_administration" {
  name = "${var.name}-jump-server-grafana-administration"
  role = module.jump_server.role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GrafanaWorkspaceAdministration"
        Effect = "Allow"
        Action = [
          "grafana:DescribeWorkspace",
          "grafana:ListPermissions",
          "grafana:UpdatePermissions",
          "grafana:CreateWorkspaceServiceAccountToken",
          "grafana:DeleteWorkspaceServiceAccountToken"
        ]
        Resource = module.grafana.workspace_arn
      }
    ]
  })
}
