#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-1200}"

AWS_DIR="$PROJECT_ROOT/aws"
K8S_DIR="$PROJECT_ROOT/k8s"
KEY_PATH="$PROJECT_ROOT/key-pair/ec2-k8s-key.pem"

step() {
  printf '\n==> %s\n' "$1"
}

step "Apply AWS infrastructure"
cd "$AWS_DIR"
terraform init
terraform apply -auto-approve

EC2_IP="$(terraform output -raw ec2_public_ip)"
ALB_DNS="$(terraform output -raw alb_dns_name)"

if [[ -z "$EC2_IP" ]]; then
  echo "Could not read ec2_public_ip from aws Terraform output" >&2
  exit 1
fi

chmod 400 "$KEY_PATH" 2>/dev/null || true

step "Wait for SSH on EC2 $EC2_IP"
start_epoch="$(date +%s)"
while true; do
  if ssh -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null \
         -o ConnectTimeout=10 \
         -i "$KEY_PATH" "ubuntu@$EC2_IP" "echo ssh-ready" >/dev/null 2>&1; then
    break
  fi

  now_epoch="$(date +%s)"
  if (( now_epoch - start_epoch > WAIT_TIMEOUT_SECONDS )); then
    echo "Timed out waiting for SSH on EC2" >&2
    exit 1
  fi

  sleep 10
done

step "Wait for EC2 user-data to finish Minikube installation"
start_epoch="$(date +%s)"
while true; do
  if ssh -o StrictHostKeyChecking=no \
         -o UserKnownHostsFile=/dev/null \
         -i "$KEY_PATH" "ubuntu@$EC2_IP" \
         "grep -q 'HOAN THANH AUTOMATION' /var/log/user-data.log"; then
    break
  fi

  now_epoch="$(date +%s)"
  if (( now_epoch - start_epoch > WAIT_TIMEOUT_SECONDS )); then
    echo "Timed out waiting for Minikube installation." >&2
    echo "Debug with: ssh -i '$KEY_PATH' ubuntu@$EC2_IP 'sudo tail -n 200 /var/log/user-data.log'" >&2
    exit 1
  fi

  echo "Waiting for user-data..."
  sleep 15
done

step "Verify Minikube and NodePort proxy"
ssh -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -i "$KEY_PATH" "ubuntu@$EC2_IP" \
    "minikube status && kubectl get nodes && sudo systemctl is-active minikube-nodeport-30080"

step "Prepare a fresh Kubernetes API SSH tunnel"
taskkill //F //IM ssh.exe >/dev/null 2>&1 || true

MINIKUBE_IP="$(ssh -o StrictHostKeyChecking=no \
                   -o UserKnownHostsFile=/dev/null \
                   -i "$KEY_PATH" "ubuntu@$EC2_IP" \
                   "sudo -u ubuntu -H minikube ip")"

if [[ -z "$MINIKUBE_IP" ]]; then
  echo "Could not read Minikube IP from EC2" >&2
  exit 1
fi

ssh -f -N \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ExitOnForwardFailure=yes \
    -i "$KEY_PATH" \
    -L "127.0.0.1:18443:$MINIKUBE_IP:8443" \
    "ubuntu@$EC2_IP"

start_epoch="$(date +%s)"
while true; do
  if curl -ksS --max-time 5 https://127.0.0.1:18443/version >/dev/null 2>&1; then
    break
  fi

  now_epoch="$(date +%s)"
  if (( now_epoch - start_epoch > 120 )); then
    echo "Timed out waiting for local Kubernetes API tunnel https://127.0.0.1:18443" >&2
    echo "Debug on EC2: ssh -i '$KEY_PATH' ubuntu@$EC2_IP 'minikube status && sudo -u ubuntu -H minikube ip'" >&2
    exit 1
  fi

  echo "Waiting for Kubernetes API tunnel..."
  sleep 5
done

step "Apply Kubernetes resources through Terraform Kubernetes provider"
cd "$K8S_DIR"
terraform init
terraform apply -auto-approve

step "Done"
echo "EC2 IP:  $EC2_IP"
echo "ALB URL: http://$ALB_DNS"
