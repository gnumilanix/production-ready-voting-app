# Terraform

The Terraform configuration separates one-time backend provisioning from the application infrastructure:

- `bootstrap/` creates the remote-state S3 bucket and its KMS encryption key. Its state is stored in that bucket at `bootstrap/terraform.tfstate`.
- `deploy/` is the application infrastructure root (VPC, EKS, node groups, EFS, controllers). Its state is stored in the same bucket at `voting-app/prod/terraform.tfstate`.

Both roots require Terraform 1.10 or newer for S3 native state locking (`use_lockfile`), so no DynamoDB table is needed. The state bucket has versioning, KMS encryption, public access blocking, and a TLS-only policy.

## One-time manual setup

Before the deploy workflow can succeed, enable an IAM Identity Center organization instance in the AWS Organizations management account using the AWS console. Enable it in the same region as the Grafana workspace (`us-east-1`); Terraform reads the instance but does not create it.

Terraform creates the Identity Center group `GrafanaAdmins`. Assign the group Grafana administrator access in the AWS or Grafana console; manage group membership in the AWS console. These changes do not require Terraform changes.

The bootstrap script `bootstrap/init/init.sh` is also a one-time manual step. It creates the GitHub Actions OIDC provider, the IAM user and role (`GitHubActionsTerraformRole`) with the policies the workflows assume, and the state bucket itself.

Run it once with an AWS identity that can create IAM and S3 resources:

```sh
cd terraform/bootstrap/init
./init.sh
```

Review the script before running — it creates IAM users, roles, and policies, and is not idempotent. The bucket name in the script must be globally unique and match the GitHub repository variable `STATE_BUCKET_NAME`.

## Automated applies with GitHub Actions

After `init.sh` has run, both roots are applied by workflows:

- [`bootstrap-terraform`](../.github/workflows/terraform-bootstrap-workflow.yaml) validates, plans, and applies `bootstrap/` on pushes and pull requests to `main`, or via manual dispatch.
- [`deploy-terraform`](../.github/workflows/terraform-deploy-workflow.yaml) does the same for `deploy/` after the bootstrap workflow completes successfully, or via manual dispatch.

Both workflows authenticate to AWS with OIDC — no stored credentials — and read the state bucket name and region from the GitHub repository variables `STATE_BUCKET_NAME` and `AWS_REGION`. The deploy workflow additionally requires the `JUMP_SERVER_SSH_CIDR` variable and the `JUMP_SERVER_PUBLIC_KEY` secret.

## Destroying and reprovisioning the application infrastructure

Run [`destroy-terraform-deploy`](../.github/workflows/terraform-destroy-workflow.yaml) manually from the Actions tab to destroy resources tracked by `deploy/`. Enter `DESTROY voting-app infrastructure` when prompted, review the destroy plan in the workflow logs, and approve the `production` environment deployment. The workflow preserves the bootstrap resources and remote state so the deploy workflow can provision the infrastructure again.

AWS schedules KMS key deletion with a minimum seven-day waiting period. The Vault initialization secret is deleted immediately so its name is available on reprovision. Destroying deploy infrastructure does not remove resources created outside Terraform, such as manually created AWS Identity Center assignments or external DNS records.

Keep local state files out of Git, and do not put credentials in backend configuration.
