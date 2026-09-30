
# production-ready-voting-app

[![.github/workflows/terraform-deploy-workflow.yaml](https://github.com/gnumilanix/production-ready-voting-app/actions/workflows/terraform-deploy-workflow.yaml/badge.svg?branch=main)](https://github.com/gnumilanix/production-ready-voting-app/actions/workflows/terraform-deploy-workflow.yaml)

Docker official voting app sample. But, production ready!

This repo aims to make Docker official sample voting app production ready by deploying it into AWS utilizing:
- EKS
- Jump server to manage EKS
- Karpenter
- ArgoCD (Including Argo rollouts and updater)
- Vault
- Amazon Managed Service for Prometheus (AMP) and Amazon Managed Grafana (AMG)

The infrastructure itself is provisioned using terraform and configured with Ansible .

Following variables and secrets needs to be configured for the repo:

**Secrets**:
- `JUMP_SERVER_PRIVATE_KEY`
- `JUMP_SERVER_PUBLIC_KEY`

**Variables**:
- `AWS_REGION`
- `JUMP_SERVER_SSH_CIDR`
- `STATE_BUCKET_NAME`