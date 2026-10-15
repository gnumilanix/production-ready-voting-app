---
name: terraform
description: 'Terraform workflow for the voting app infrastructure. Use when: editing .tf files, adding AWS resources or IAM policies, running terraform plan/apply, validating Sentinel policies, or debugging terraform-pr/deploy workflow failures. Covers the bootstrap/deploy stack split, module layout, AWS profile usage, sentinel fmt/test, and the iamlive least-privilege IAM workflow.'
---

# Terraform

## When to Use

- Editing files under `terraform/` (stacks, modules, sentinel policies)
- Adding or changing AWS resources, IAM roles, or policies
- Running `terraform plan` / `apply` locally or debugging CI failures in the
  `terraform-pr` or `deploy-terraform` workflows
- Adding or fixing Sentinel policies in `terraform/sentinel/`

## Stack layout

Two separate roots, each with its own state:

| Stack | Path | State key | Purpose |
|-------|------|-----------|---------|
| bootstrap | `terraform/bootstrap` | `bootstrap/terraform.tfstate` | State backend (S3 + KMS, native locking) and pipeline IAM identity |
| deploy | `terraform/deploy` | `voting-app/prod/terraform.tfstate` | Application infra (VPC, EKS, EFS, controllers, AMG/AMP) |

Shared modules live in `terraform/modules/` (eks, vpc, karpenter, vault,
grafana, amp, jump-server, aws-load-balancer-controller). The deploy workflow
triggers on changes to `terraform/deploy/**`, `terraform/modules/**`, and
`ansible/**`.

## AWS profiles

Always set `AWS_PROFILE` explicitly — never rely on the default profile:

- `AWS_PROFILE=terraform-user` — local plan/validate/console CLI operations
- `AWS_PROFILE=bitbucket` — privileged apply operations (IAM changes)
- Region is always `us-east-1`.

## Local workflow

```sh
cd terraform/deploy
AWS_PROFILE=terraform-user terraform init -backend-config=backend.hcl
AWS_PROFILE=terraform-user terraform fmt -recursive
AWS_PROFILE=terraform-user terraform validate
AWS_PROFILE=terraform-user terraform plan
```

Bootstrap stack: same commands in `terraform/bootstrap`. Do not run `apply`
locally unless explicitly asked — applies happen via GitHub Actions.

## Sentinel policies

All deploy changes must pass the policy set in `terraform/sentinel/`
(hard-mandatory):

- `allowed-instance-sizes` — micro/small/medium instances only
- `no-public-write-buckets` — no public S3 buckets
- `restrict-ingress-cidr` — no `0.0.0.0/0` ingress except the jump server
- `eks-min-version` — EKS >= 1.35
- `eks-no-public-endpoint` — no public EKS endpoint
- `enforce-region` — `us-east-1` only
- `nodegroup-max-size` — node group `max_size <= 4`

Policy sources sit at `terraform/sentinel/*.sentinel`, shared helpers in
`terraform/sentinel/modules/common/`, and per-policy test fixtures in
`terraform/sentinel/test/<policy>/`. The CI workflow generates
`mock-tfplan.sentinel` from plan JSON via
`.github/scripts/generate-sentinel-mock.py` and runs `sentinel apply`.

Validate locally before pushing:

```sh
cd terraform/sentinel
sentinel fmt -check=true $(find . -name '*.sentinel')
sentinel test
```

When adding a new policy: create the `.sentinel` file, register it in
`sentinel.hcl` (with `enforcement_level`), and add a `test/<policy>/`
directory with pass/fail fixtures.

## IAM policy workflow

Never hand-write broad permissions. Capture the exact API calls with iamlive:

1. Run `iamlive --output-file <file>.json` in one shell
2. Exercise the workload (e.g. `terraform apply`, or the CLI/SDK calls)
3. Translate the captured actions into Terraform IAM policy statements,
   scoped to specific resource ARNs where possible

The `bootstrap/init/` JSON policies are published with
`aws iam create-policy-version`. AWS caps a policy at 5 versions — delete the
oldest non-default version before publishing a new one:

```sh
AWS_PROFILE=bitbucket aws iam list-policy-versions --policy-arn <arn>
AWS_PROFILE=bitbucket aws iam delete-policy-version --policy-arn <arn> --version-id <oldest-non-default>
AWS_PROFILE=bitbucket aws iam create-policy-version --policy-arn <arn> \
  --policy-document file://<policy>.json --set-as-default
```

Validate JSON policies against the IAM console editor or
`aws iam simulate-principal-policy` before publishing — invalid action names
fail silently in some tooling.

## Conventions

- Format with `terraform fmt -recursive` before committing
- New shared infrastructure goes in `terraform/modules/<name>/`; keep root
  stacks thin
- Never commit local state files or credentials in backend configuration
