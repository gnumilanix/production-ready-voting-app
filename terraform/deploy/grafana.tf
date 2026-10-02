# IAM Identity Center (SSO) organization instance used for AMG authentication.
# Enable it once from the AWS Organizations management account in the console
# in us-east-1; Terraform discovers the instance and its GrafanaAdmins group.
data "aws_ssoadmin_instances" "main" {}

locals {
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.main.arns)[0]
}

resource "aws_identitystore_group" "grafana_admins" {
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

resource "aws_grafana_workspace" "main" {
  name                     = "${var.name}-grafana"
  description              = "Grafana for ${var.name} AMP metrics."
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana_workspace.arn
  data_sources             = ["PROMETHEUS"]

  tags = {
    Name = "${var.name}-grafana"
  }
}

# Grant the Identity Center admin group Grafana admin rights.
resource "aws_grafana_role_association" "admin" {
  workspace_id = aws_grafana_workspace.main.id
  role         = "ADMIN"
  group_ids    = [aws_identitystore_group.grafana_admins.group_id]
}
