data "aws_ssm_parameter" "eks_al2023_ami" {
  name = "/aws/service/eks/optimized-ami/${aws_eks_cluster.main.version}/amazon-linux-2023/x86_64/standard/recommended/image_id"
}

data "cloudinit_config" "eks_nodes" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "application/node.eks.aws"
    content = templatefile("${path.module}/eks-nodeconfig.tftpl", {
      cluster_name                  = aws_eks_cluster.main.name
      cluster_endpoint              = aws_eks_cluster.main.endpoint
      cluster_certificate_authority = aws_eks_cluster.main.certificate_authority[0].data
      cluster_service_cidr          = aws_eks_cluster.main.kubernetes_network_config[0].service_ipv4_cidr
    })
  }
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.name}-eks-al2023-t3-small-"
  image_id    = data.aws_ssm_parameter.eks_al2023_ami.value
  user_data   = data.cloudinit_config.eks_nodes.rendered

  lifecycle {
    create_before_destroy = true
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
  labels         = each.value.labels

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = tostring(aws_launch_template.eks_nodes.latest_version)
  }

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