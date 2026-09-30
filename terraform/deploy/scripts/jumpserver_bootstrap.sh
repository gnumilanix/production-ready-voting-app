#!/bin/bash
curl -LO https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl
install -m 0755 ./kubectl /usr/local/bin/kubectl
mkdir -p /home/ec2-user/.kube
aws eks update-kubeconfig --region us-east-1 --name ${cluster_name} --kubeconfig /home/ec2-user/.kube/config
chown -R ec2-user:ec2-user /home/ec2-user/.kube