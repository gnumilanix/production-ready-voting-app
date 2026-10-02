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

Terraform provisions the infrastructure, and Ansible configures the cluster. A `kube-prometheus-stack` agent (no in-cluster Grafana) scrapes cluster metrics and remote-writes them to AMP via EKS Pod Identity.

### Architecture overview

```mermaid
flowchart TD
    subgraph GHA["GitHub Actions"]
        BOOT["bootstrap-terraform<br/>state backend + IAM identity"]
        DEPLOY["deploy-terraform<br/>infrastructure + cluster config"]
        BUILD["build-app-images"]
    end

    GHCR["GHCR image registry"]

    subgraph AWS["AWS"]
        STATE[("S3 + KMS<br/>Terraform state")]
        subgraph VPC["VPC"]
            JUMP["Jump server"]
            subgraph EKS["EKS cluster (Karpenter-managed nodes)"]
                ARGO["Argo CD<br/>+ Rollouts + Image Updater"]
                VAULT["Vault (EFS-backed)"]
                subgraph APP["Voting app"]
                    VOTE["vote (Python)"]
                    REDIS[("Redis")]
                    WORKER["worker (.NET)"]
                    DB[("PostgreSQL")]
                    RESULT["result (Node.js)"]
                end
            end
        end
        OBS["AMP + AMG"]
    end

    BOOT -->|creates| STATE
    BOOT -->|workflow_run| DEPLOY
    DEPLOY -->|Terraform apply| VPC
    DEPLOY -->|Ansible over SSH| JUMP
    JUMP -->|installs| ARGO
    JUMP -->|initializes + configures| VAULT
    BUILD -->|pushes images| GHCR
    GHCR -->|new tags| ARGO
    ARGO -->|GitOps sync of argo/ manifests| APP
    VAULT -->|postgres-creds| APP
    VOTE --> REDIS --> WORKER --> DB --> RESULT
    EKS -.->|metrics| OBS
```

### Project layout

- **terraform/**: All infrastructure as code. `bootstrap/` provisions the Terraform state backend (S3, DynamoDB) and the IAM identity the pipeline runs as; `deploy/` provisions the application infrastructure (VPC, EKS, node groups, EFS, controllers, IAM).
- **ansible/**: Cluster configuration playbooks run against the jump server after the infrastructure is up — installs Argo CD and its applications, and initializes/configures Vault.
- **argo/**: Kubernetes manifests managed by Argo CD (GitOps) — the voting app, Vault, Karpenter, Rollouts, Image Updater, and shared Gateway API prerequisites.
- **app/**: The voting app source and Dockerfiles — `vote` (Python web UI), `worker` (.NET vote processor), `result` (Node.js results UI), and `seed-data`.

### Prerequisite
Configure the following GitHub Actions secrets and variables:

**Secrets**:
- `JUMP_SERVER_PRIVATE_KEY`: OpenSSH private key used by the configure job to SSH into the jump server; must correspond to `JUMP_SERVER_PUBLIC_KEY`.
- `JUMP_SERVER_PUBLIC_KEY`: OpenSSH public key installed on the jump server; Terraform injects it into the EC2 key pair.
- `ARGOCD_REPO_TOKEN`: GitHub token used by Argo CD / Image Updater to read this repository and write back image tags.

Ansible generates the PostgreSQL password and writes it to Vault at `secret/postgres-creds`.

**Variables**:
- `AWS_REGION`: AWS region all infrastructure is deployed to (for example `us-east-1`).
- `STATE_BUCKET_NAME`: Name of the S3 bucket holding Terraform state; must match the bucket created by the bootstrap workflow.
- `JUMP_SERVER_SSH_CIDR`: IPv4 CIDR allowed to SSH to the jump server (restrict to your own IP, for example `203.0.113.10/32`; do not use `0.0.0.0/0`).

**Prerequisite**: The bootstrap identity needs permission to create IAM users, roles, and policies.

### Workflows

- **bootstrap-terraform** ([terraform-bootstrap-workflow.yaml](.github/workflows/terraform-bootstrap-workflow.yaml)): Runs on pushes/PRs to `main` that touch `terraform/bootstrap`, and provisions the foundational state backend (S3 bucket, DynamoDB locking) and IAM identity used by the deploy pipeline.
- **deploy-terraform** ([terraform-deploy-workflow.yaml](.github/workflows/terraform-deploy-workflow.yaml)): Triggered after a successful bootstrap run (or manually); validates, plans, applies the `terraform/deploy` infrastructure (VPC, EKS, node groups, EFS, controllers), then configures the cluster with Ansible (Argo CD, Vault, app bootstrap).
- **build-app-images** ([build-app-images.yaml](.github/workflows/build-app-images.yaml)): Runs when files under `app/` change; builds the changed component images (vote, result, worker, seed-data) and pushes them to GHCR with `main-latest` and commit-SHA tags for Argo Image Updater to roll out.

### EKS console access

Terraform creates an IAM role `${var.name}-eks-console-role` with read-only cluster access. To grant a user or role EKS console access, add its ARN to that role's trust policy (in the AWS IAM console or via `aws iam update-assume-role-policy`), then have the user assume the role with a console role-switch.