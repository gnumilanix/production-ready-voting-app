# IAM Identity Center (SSO) organization instance used for AMG authentication.
# Enable it once from the AWS Organizations management account in the console
# in us-east-1; Terraform discovers the instance and its GrafanaAdmins group.
data "aws_ssoadmin_instances" "main" {
  provider = aws.grafana
}

locals {
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

resource "aws_identitystore_group" "grafana_admins" {
  provider          = aws.grafana
  identity_store_id = local.identity_store_id
  display_name      = "GrafanaAdmins"
  description       = "Administrators for the Amazon Managed Grafana workspace."
}

resource "aws_iam_role" "grafana_workspace" {
  name = "${var.name}-grafana-workspace-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "grafana.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name      = "${var.name}-grafana-workspace-role"
    Component = "grafana"
  }
}

resource "aws_iam_role_policy" "grafana_amp_query" {
  name = "${var.name}-grafana-amp-query"
  role = aws_iam_role.grafana_workspace.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "aps:QueryMetrics",
        "aps:GetLabels",
        "aps:GetSeries",
        "aps:GetMetricMetadata"
      ]
      Resource = var.amp_workspace_arn
    }]
  })
}

resource "aws_grafana_workspace" "main" {
  provider = aws.grafana

  name                     = "${var.name}-grafana"
  description              = "Grafana for ${var.name} AMP metrics."
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana_workspace.arn
  data_sources             = ["PROMETHEUS"]

  depends_on = [aws_iam_role_policy.grafana_amp_query]

  tags = {
    Name = "${var.name}-grafana"
  }
}

resource "aws_grafana_workspace_service_account" "datasource_provisioner" {
  provider = aws.grafana

  name         = "${var.name}-datasource-provisioner"
  grafana_role = "ADMIN"
  workspace_id = aws_grafana_workspace.main.id
}

# The workspace is created in SERVICE_MANAGED mode, but IAM Identity Center
# group-to-Grafana admin assignment is not reliable via Terraform when the AWS
# managed application update path rejects the SSO mutation. Assign the group in
# the AWS console or Grafana console instead.
