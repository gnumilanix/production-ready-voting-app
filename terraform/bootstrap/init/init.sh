# IAM identity provider for github actions
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com
  
# IAM policy for terraform backend
aws iam create-policy \
  --policy-name GitHubTerraformS3BackendPolicy \
  --policy-document file://backend-policy.json

# IAM user, roles and policies for terraform
aws iam create-user --user-name terraform-user

aws iam attach-user-policy \
  --user-name terraform-user \
  --policy-arn arn:aws:iam::365020425296:policy/GitHubTerraformS3BackendPolicy

aws iam create-access-key --user-name terraform-user

aws iam create-role \
  --role-name GitHubActionsTerraformRole \
  --assume-role-policy-document file://oidc-policy.json

aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::365020425296:policy/GitHubTerraformS3BackendPolicy

# IAM least previlage policy for terraform user
aws iam create-policy \
  --policy-name TerraformExecutionPolicy \
  --policy-document file://terraform-policy.json
  
aws iam attach-user-policy \
  --user-name terraform-user \
  --policy-arn arn:aws:iam::365020425296:policy/TerraformExecutionPolicy
  
aws iam attach-role-policy \
  --role-name GitHubActionsTerraformRole \
  --policy-arn arn:aws:iam::365020425296:policy/TerraformExecutionPolicy

# Bucket for bootstrap tf state
aws s3api create-bucket \
  --bucket flamingo-voting-app-tfstate \
  --region us-east-1

# Tool for generating iam policy based on terraform plan
brew install iann0036/iamlive/iamlive
