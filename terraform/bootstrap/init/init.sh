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

create_and_attach_policy() {
  local policy_name="$1"
  local policy_document="$2"
  local policy_arn="arn:aws:iam::365020425296:policy/${policy_name}"

  aws iam create-policy \
    --policy-name "$policy_name" \
    --policy-document "file://${policy_document}"

  aws iam attach-user-policy \
    --user-name terraform-user \
    --policy-arn "$policy_arn"

  aws iam attach-role-policy \
    --role-name GitHubActionsTerraformRole \
    --policy-arn "$policy_arn"
}

create_and_attach_policy TerraformDiscoveryPolicy terraform-discovery-policy.json
create_and_attach_policy TerraformNetworkPolicy terraform-network-policy.json
create_and_attach_policy TerraformComputePolicy terraform-compute-policy.json
create_and_attach_policy TerraformEksPolicy terraform-eks-policy.json
create_and_attach_policy TerraformIamPolicy terraform-iam-policy.json
create_and_attach_policy TerraformPodIdentityPassRolePolicy pod-identity-pass-role-policy.json

# Bucket for bootstrap tf state
aws s3api create-bucket \
  --bucket flamingo-voting-app-tfstate \
  --region us-east-1

# Tool for generating iam policy based on terraform plan
brew install iann0036/iamlive/iamlive
