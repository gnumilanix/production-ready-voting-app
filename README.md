# Production-Ready Voting App

[![.github/workflows/terraform-deploy-workflow.yaml](https://github.com/gnumilanix/production-ready-voting-app/actions/workflows/terraform-deploy-workflow.yaml/badge.svg?branch=main)](https://github.com/gnumilanix/production-ready-voting-app/actions/workflows/terraform-deploy-workflow.yaml)

This project deploys Docker's official voting app sample to AWS with production-oriented infrastructure and operations.

It uses:
- EKS
- A jump server to manage EKS
- Karpenter
- Argo CD, including Argo Rollouts and Image Updater
- Vault (data stored on Amazon EFS)
- Amazon Managed Service for Prometheus (AMP) and Amazon Managed Grafana (AMG)

Terraform provisions the infrastructure, and Ansible configures the cluster.

Configure the following GitHub Actions secrets and variables:

**Secrets**:
- `JUMP_SERVER_PRIVATE_KEY`
- `JUMP_SERVER_PUBLIC_KEY`
- `ARGOCD_REPO_TOKEN`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`

Add these secrets to the GitHub `production` environment. Ansible writes the PostgreSQL credentials to Vault at `secret/postgres-creds`.

**Variables**:
- `AWS_REGION`
- `STATE_BUCKET_NAME`
- `JUMP_SERVER_SSH_CIDR`
- `EKS_CONSOLE_PRINCIPAL_ARN`

**Prerequisite**: The bootstrap identity needs permission to create IAM users, roles, and policies.