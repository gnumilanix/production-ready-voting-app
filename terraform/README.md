# Terraform

The Terraform configuration separates one-time backend provisioning from the app infrastructure:

- `bootstrap/` creates the remote-state S3 bucket and KMS key. After initial provisioning, its state is stored at `bootstrap/terraform.tfstate` in that bucket.
- `app/` is the application infrastructure root and uses the provisioned S3 bucket with native S3 state locking.

Both roots require Terraform 1.10 or newer for S3 lockfile support.

## Bootstrap the backend

Use an AWS identity with permission to create KMS and S3 resources. The backend bucket must exist before `terraform init` can use it. For the first run only, temporarily disable the S3 backend declaration and create the bucket using local state:

```sh
cd terraform/bootstrap
mv backend.tf backend.tf.s3
terraform init -reconfigure
terraform plan -var='aws_region=us-east-1' -var='state_bucket_name=YOUR_STATE_BUCKET_NAME'
terraform apply -var='aws_region=us-east-1' -var='state_bucket_name=YOUR_STATE_BUCKET_NAME'
```

Use the exact bucket name and region configured as GitHub repository variables `STATE_BUCKET_NAME` and `AWS_REGION`. The name must be globally unique. Review the plan before applying; if a previous local apply partially created resources, Terraform will use the local state to continue from there.

## Move bootstrap state to S3

After a successful local apply creates the S3 bucket, migrate the existing local state into the same bucket. Do this before pushing the S3 backend configuration to the branch that triggers GitHub Actions, so CI does not initialize an empty state first.

```sh
mv backend.tf.s3 backend.tf
terraform init -migrate-state \
  -backend-config='bucket=YOUR_STATE_BUCKET_NAME' \
  -backend-config='key=bootstrap/terraform.tfstate' \
  -backend-config='region=us-east-1' \
  -backend-config='encrypt=true' \
  -backend-config='kms_key_id=arn:aws:kms:us-east-1:365020425296:alias/voting-app-terraform-state'
```

Run this migration before pushing the backend configuration that triggers the GitHub Actions plan/apply workflow. The state bucket is created by this root, so CI cannot use it until the one-time local bootstrap and migration are complete. Afterward, both CI jobs use the persistent `bootstrap/terraform.tfstate` key.

The bootstrap and deploy roots use separate state keys in the same bucket; no second bucket or lock table is needed. GitHub Actions uses the repository variables `STATE_BUCKET_NAME` and `AWS_REGION` to initialize the bootstrap backend consistently. Keep local state files out of Git. The S3 bucket has versioning, KMS encryption, public access blocking, enforced bucket ownership, and a TLS-only policy. S3 lockfiles are enabled by the backend configuration. Bucket and KMS key deletion are guarded by Terraform lifecycle rules.

## Initialize app state

Copy `app/backend.hcl.example` to `app/backend.hcl` and set the bucket and region. The configured backend key defaults to `voting-app/dev/terraform.tfstate`.

```sh
cd terraform/app
terraform init -backend-config=backend.hcl
terraform validate
```

Use an AWS role or other short-lived credentials from the standard AWS credential chain. Do not put credentials in backend configuration or commit state files. The app root is ready for resources to be added; environment-specific state keys should remain separate.