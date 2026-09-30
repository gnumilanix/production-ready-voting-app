# production-ready-voting-app
[![.github/workflows/terraform-deploy-workflow.yaml](https://github.com/gnumilanix/production-ready-voting-app/actions/workflows/terraform-deploy-workflow.yaml/badge.svg?branch=main)](https://github.com/gnumilanix/production-ready-voting-app/actions/workflows/terraform-deploy-workflow.yaml)
Docker official voting app sample. But, production ready!

## Configure kubectl on the jump server

The deploy workflow runs `ansible/install-kubectl.yml` after Terraform apply, targeting the IP from the `jump_server_public_ip` Terraform output. Add the GitHub Actions secret `JUMP_SERVER_PRIVATE_KEY` with the private key matching `JUMP_SERVER_PUBLIC_KEY`. If the runner is outside the configured SSH CIDR, the workflow temporarily allows its `/32` address and revokes that ingress rule when the playbook completes.
