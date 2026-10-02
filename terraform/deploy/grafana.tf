# IAM Identity Center (SSO) instance used for AMG authentication. An IdC
# instance cannot be created by Terraform — enable it once in us-east-1
# (console or `aws sso-admin create-instance`), then it is referenced here.
# AMG requires the workspace to be in the same region as the IdC instance.
data "aws_ssoadmin_instances" "main" {}

locals {
  identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.main.arns)[0]
}

data "aws_identitystore_group" "grafana_admins" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "GrafanaAdmins"
    }
  }
}

resource "aws_grafana_workspace" "main" {
  name                     = "${var.name}-grafana"
  description              = "Grafana for ${var.name} AMP metrics."
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  data_sources             = ["PROMETHEUS"]

  tags = {
    Name = "${var.name}-grafana"
  }
}

# Grant the Identity Center admin group Grafana admin rights.
resource "aws_grafana_role_association" "admin" {
  workspace_id = aws_grafana_workspace.main.id
  role         = "ADMIN"
  group_ids    = [data.aws_identitystore_group.grafana_admins.group_id]
}
