# Copilot Instructions

## Project overview
Production-ready voting app: EKS + Karpenter on AWS (us-east-1 only), Terraform
(bootstrap + deploy stacks), Ansible configuration via jump server, Argo CD
GitOps, HashiCorp Vault, Prometheus/Grafana, GitHub Actions CI/CD.

## AWS
- Region is always `us-east-1`; never introduce another region.
- Terraform plan/validation locally: `AWS_PROFILE=terraform-user`.
- Privileged AWS apply operations (IAM etc.): `AWS_PROFILE=bitbucket`.
- AWS console CLI operations: `AWS_PROFILE=terraform-user`. Never rely on default profile.
- When adding IAM policies, use iamlive to capture the exact API calls and
  generate least-privilege policy statements instead of hand-writing broad
  permissions. Run `iamlive` with `--output-file` against the workload, then
  translate the captured actions into Terraform IAM resources.

## Git
- Never `git push` automatically.
- All commits must follow conventional commits: `type: description`.
  Allowed types: `add`, `fix`, `feat`, `chore`, `refactor`, `docs`, `style`.
  Do not invent non-standard prefixes (e.g. `upt:`) — pick the closest type.

## Terraform
- Stacks: terraform/bootstrap (state bucket, OIDC) and terraform/deploy (infra).
- Modules live in terraform/modules/.
- All changes must pass the Sentinel policy set in terraform/sentinel/
  (instance sizes micro/small/medium, no public buckets, no 0.0.0.0/0 ingress
  except jump server, EKS >= 1.35, no public EKS endpoint, us-east-1 only,
  node group max_size <= 4).
- Validate policies locally before pushing:
  `cd terraform/sentinel && sentinel fmt -check=true $(find . -name '*.sentinel') && sentinel test`

## GitHub Actions
- Workflows: bootstrap (push to main, bootstrap paths only), deploy
  (workflow_run after bootstrap or push on deploy paths), destroy (manual),
  terraform-pr (validate + sentinel fmt/test + plan with policy evaluation).
- OIDC role: GitHubActionsTerraformRole; subject format includes numeric IDs
  (repo:owner@id/repo@id:...); trust policy uses StringLike wildcards.
- Environment `production` gates deploy/configure/destroy jobs (2h timeout).

## Ansible
- Playbooks run on the jump server over SSH from GitHub Actions.
- ansible/ansible.cfg sets SSH keepalives — long `helm --wait`/`kubectl wait`
  tasks depend on it; don't remove.
- Jump server is t3.small; keep memory-heavy operations minimal.

## Argo CD
- Destroy flow: no sync windows. `argocd app delete` must use bare app names
  (strip the `argocd/` prefix) or it fails with PermissionDenied (rc 20).
- Karpenter resources (NodePool/NodeClaims/EC2NodeClass) are deleted via
  kubectl before the Argo CD cascade delete.
- NetworkPolicy enforcement is enabled on the VPC CNI (`enableNetworkPolicy`);
  connectivity changes between voting app components require updating the
  NetworkPolicies in argo/voting/.

## Coding conventions
- Keep workflows clean: no heredoc Python or inline shell logic — extract
  scripts to .github/scripts/.
- Pin tool versions via shared env vars (e.g. SENTINEL_VERSION).
