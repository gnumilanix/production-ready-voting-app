resource "aws_prometheus_workspace" "main" {
  alias = "${var.name}-amp"

  tags = {
    Name = "${var.name}-amp"
  }
}

resource "aws_iam_policy" "amp_remote_write" {
  name        = "${var.name}-amp-remote-write-policy"
  description = "Allows remote write into the ${var.name} AMP workspace."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "aps:RemoteWrite",
        "aps:QueryMetrics",
        "aps:GetSeries",
        "aps:GetLabels",
        "aps:GetMetricMetadata"
      ]
      Resource = aws_prometheus_workspace.main.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "amp_remote_write" {
  role       = aws_iam_role.pod_identity["prometheus-exporter"].name
  policy_arn = aws_iam_policy.amp_remote_write.arn
}

resource "aws_eks_pod_identity_association" "prometheus" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "monitoring"
  service_account = "kube-metrics-amp-prometheus"
  role_arn        = aws_iam_role.pod_identity["prometheus-exporter"].arn

  depends_on = [aws_eks_addon.managed["eks-pod-identity-agent"]]
}
