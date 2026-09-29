aws iam create-user --user-name terraform-user

aws iam put-user-policy \
  --user-name terraform-user \
  --policy-name TerraformS3BackendPolicy \
  --policy-document file://user-policy.json

aws iam create-access-key --user-name terraform-user

aws iam create-role \
  --role-name GitHubActionsTerraformRole \
  --assume-role-policy-document file://oidc-policy.json

terraform init
terraform plan -var='aws_region=us-east-1' -var='state_bucket_name=voting-app-tfstate'
terraform apply -var='aws_region=us-east-1' -var='state_bucket_name=voting-app-tfstate'