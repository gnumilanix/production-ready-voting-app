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
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    "aws-ebs-csi-driver" = {
      role_key             = "ebs-csi"
      service_account      = "ebs-csi-controller-sa"
      configuration_values = null
    }
  }

  eks_node_groups = {
    "spot-small-general" = {
      desired_size = 2
      min_size     = 1
      max_size     = 4
      labels       = {}
      taints       = []
    }
    "spot-small-stateful" = {
      desired_size = 1
      min_size     = 1
      max_size     = 2
      labels = {
        "workload-type" = "${var.name}-spot-stateful"
      }
      taints = [{
        key    = "workload-type"
        value  = "${var.name}-spot-stateful"
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