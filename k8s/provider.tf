terraform {
  required_version = ">= 1.0.0"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }
  }
}
# đọc layer 1 để lấy IP Public và DNS của ALB
data "terraform_remote_state" "aws_infra" {
  backend = "local"
  config = {
    path = "${path.module}/../aws/terraform.tfstate"
  }
}

locals {
  ssh_key_path       = "../key-pair/ec2-k8s-key.pem"
  ec2_ssh_user       = "ubuntu"
  ec2_public_ip      = data.terraform_remote_state.aws_infra.outputs.ec2_public_ip
  minikube_api_port  = 18443
  ssh_common_options = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
}

# Tạo SSH tunnel local 127.0.0.1:18443 -> $(minikube ip):8443 trên EC2.
data "external" "minikube_api_tunnel" {
  program = [
    "bash", "-c",
    <<-EOT
      set -e

      if (echo >/dev/tcp/127.0.0.1/${local.minikube_api_port}) >/dev/null 2>&1; then
        echo '{"host":"https://127.0.0.1:${local.minikube_api_port}"}'
        exit 0
      fi

      MINIKUBE_IP=$(ssh ${local.ssh_common_options} -i ${local.ssh_key_path} ${local.ec2_ssh_user}@${local.ec2_public_ip} 'sudo -u ubuntu -H minikube ip')
      ssh -f -N \
        ${local.ssh_common_options} \
        -o ExitOnForwardFailure=yes \
        -i ${local.ssh_key_path} \
        -L 127.0.0.1:${local.minikube_api_port}:$${MINIKUBE_IP}:8443 \
        ${local.ec2_ssh_user}@${local.ec2_public_ip}

      sleep 2
      echo '{"host":"https://127.0.0.1:${local.minikube_api_port}"}'
    EOT
  ]
}

# Đọc file Client Certificate từ Minikube trên EC2
data "external" "minikube_cert" {
  program = [
    "bash", "-c",
    "DATA=$(ssh ${local.ssh_common_options} -i ${local.ssh_key_path} ${local.ec2_ssh_user}@${local.ec2_public_ip} 'sudo base64 -w0 /home/ubuntu/.minikube/profiles/minikube/client.crt'); printf '{\"data\":\"%s\"}\\n' \"$DATA\""
  ]
}

# Client Key từ Minikube trên EC2
data "external" "minikube_key" {
  program = [
    "bash", "-c",
    "DATA=$(ssh ${local.ssh_common_options} -i ${local.ssh_key_path} ${local.ec2_ssh_user}@${local.ec2_public_ip} 'sudo base64 -w0 /home/ubuntu/.minikube/profiles/minikube/client.key'); printf '{\"data\":\"%s\"}\\n' \"$DATA\""
  ]
}

#CA Certificate từ Minikube trên EC2
data "external" "minikube_ca" {
  program = [
    "bash", "-c",
    "DATA=$(ssh ${local.ssh_common_options} -i ${local.ssh_key_path} ${local.ec2_ssh_user}@${local.ec2_public_ip} 'sudo base64 -w0 /home/ubuntu/.minikube/ca.crt'); printf '{\"data\":\"%s\"}\\n' \"$DATA\""
  ]
}

# Wire thông số chứng chỉ vào Kubernetes Provider

provider "kubernetes" {
  host = data.external.minikube_api_tunnel.result.host

  client_certificate     = base64decode(data.external.minikube_cert.result.data)
  client_key             = base64decode(data.external.minikube_key.result.data)
  cluster_ca_certificate = base64decode(data.external.minikube_ca.result.data)
}
