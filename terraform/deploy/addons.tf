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

resource "aws_iam_role_policy_attachment" "efs_csi" {
  role       = aws_iam_role.pod_identity["efs-csi"].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
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
  configuration_values        = each.value.configuration_values

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
    aws_iam_role_policy_attachment.ebs_csi,
    aws_iam_role_policy_attachment.efs_csi
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
  namespace       = "argo-rollouts"
  service_account = "argo-rollouts"
  role_arn        = aws_iam_role.pod_identity["argocd"].arn

  depends_on = [aws_eks_addon.managed["eks-pod-identity-agent"]]
}