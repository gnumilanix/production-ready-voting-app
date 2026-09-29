aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com
  
aws iam create-policy \
  --policy-name GitHubTerraformS3BackendPolicy \
  --policy-document file://backend-policy.json

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