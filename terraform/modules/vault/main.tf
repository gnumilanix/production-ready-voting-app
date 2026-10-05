data "aws_caller_identity" "current" {}

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

resource "aws_iam_role" "pod_identity" {
  name = "${var.name}-vault-pod-identity-role"

  assume_role_policy = jsonencode({
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
          "aws:SourceArn" = var.cluster_arn
        }
      }
    }]
  })

  tags = {
    Name      = "${var.name}-vault-pod-identity-role"
    Component = "vault"
  }
}

resource "aws_iam_role_policy" "vault_kms_unseal" {
  name = "${var.name}-vault-kms-unseal"
  role = aws_iam_role.pod_identity.name

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
  cluster_name    = var.cluster_name
  namespace       = "vault"
  service_account = "vault"
  role_arn        = aws_iam_role.pod_identity.arn

  depends_on = [aws_iam_role_policy.vault_kms_unseal]
}
