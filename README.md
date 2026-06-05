# Terraform EC2 Minikube ALB Lab

Project nay dung Terraform de tu dong:

- Tao ha tang AWS: VPC, public subnets, Security Groups, EC2, ALB, Target Group.
- Cai Minikube tren 1 EC2 bang `user_data`.
- Wire Terraform Kubernetes provider vao Minikube tren EC2.
- Deploy app nho `nginx:alpine`.
- Expose app ra internet qua AWS ALB.

## Kien Truc

```text
User Browser
  |
  | HTTP :80
  v
AWS Application Load Balancer
  |
  | Target Group -> EC2 :30080
  v
EC2 Ubuntu
  |
  | socat proxy
  | EC2:30080 -> $(minikube ip):30080
  v
Minikube NodePort Service :30080
  |
  v
Nginx Pods :80
```

Luồng Terraform provider:

```text
Terraform AWS provider
  -> tao VPC, EC2, ALB
  -> EC2 user_data cai Docker, kubectl, Minikube

Terraform Kubernetes provider
  -> doc EC2 public IP tu aws/terraform.tfstate
  -> SSH vao EC2
  -> lay Minikube client cert/key/CA
  -> mo SSH tunnel 127.0.0.1:18443 -> $(minikube ip):8443
  -> deploy Deployment va Service vao Minikube
```

## Yeu Cau Truoc Khi Chay

May local can co:

- Terraform.
- AWS credentials da cau hinh.
- Git Bash hoac PowerShell co `ssh`.
- AWS key pair ten `ec2-k8s-key`.
- File private key local tai `key-pair/ec2-k8s-key.pem`.

File `aws/terraform.tfvars` can co gia tri phu hop:

```hcl
key_name      = "ec2-k8s-key"
instance_type = "c7i-flex.large"
my_ip         = "YOUR_PUBLIC_IP/32"
```

## Cach Chay One-Click

Khuyen nghi dung Git Bash:

```bash
cd /d/terraform/lab6-4
bash one-click-apply.sh
```

Script nay se tu dong:

```text
1. terraform init/apply trong aws
2. lay EC2 public IP va ALB DNS
3. doi SSH vao EC2 san sang
4. doi user_data cai xong Minikube
5. kiem tra Minikube va NodePort proxy
6. terraform init/apply trong k8s
7. in ra ALB URL
```

Neu EC2 cai Minikube lau:

```bash
WAIT_TIMEOUT_SECONDS=1800 bash one-click-apply.sh
```

Neu file key bi loi permission trong Git Bash:

```bash
chmod 400 key-pair/ec2-k8s-key.pem
```

Sau khi chay xong, script se in:

```text
ALB URL: http://...
```

Mo URL do tren browser de xem nginx.

## Cach Chay Thu Cong

Neu khong dung script, chay theo thu tu:

```bash
cd /d/terraform/lab6-4/aws
terraform init
terraform apply
```

Lay EC2 IP:

```bash
terraform output ec2_public_ip
```

SSH vao EC2 va doi user-data xong:

```bash
ssh -i ../key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
sudo tail -f /var/log/user-data.log
```

Chi chay layer `k8s` sau khi log co:

```text
=== HOAN THANH AUTOMATION ===
```

Chay Kubernetes layer:

```bash
cd /d/terraform/lab6-4/k8s
terraform init
terraform apply
```

Lay URL:

```bash
terraform output final_web_url
```

## Cach Xoa

Xoa Kubernetes resources truoc:

```bash
cd /d/terraform/lab6-4/k8s
terraform destroy
```

Sau do xoa AWS infrastructure:

```bash
cd /d/terraform/lab6-4/aws
terraform destroy
```

Ly do phai xoa `k8s` truoc: Kubernetes provider con can SSH/tunnel vao EC2 de xoa Deployment va Service. Neu xoa EC2 truoc, provider khong con cluster de ket noi.

## Ly Do Thiet Ke

### Vi sao chon EC2 + Minikube

De bai yeu cau dung 1 EC2 va bat Minikube hoac kind ben trong. Minikube phu hop vi nhe, de cai bang script, va du de deploy app demo `nginx:alpine`.

### Vi sao tach `aws` va `k8s`

Kubernetes provider can Kubernetes API va certificate san sang. Nhung Minikube chi ton tai sau khi EC2 boot xong va `user_data` cai xong.

Neu ep tat ca vao mot `terraform apply` duy nhat, provider Kubernetes co the duoc cau hinh khi Minikube chua ready. Vi vay project tach thanh 2 layer va dung wrapper script de tao trai nghiem one-click on dinh.

### Vi sao wire provider bang SSH tunnel va cert

Minikube chay bang Docker driver tren EC2, nen Kubernetes API khong public truc tiep qua `https://EC2_PUBLIC_IP:8443`.

Layer `k8s` doc EC2 public IP tu remote state:

```hcl
data "terraform_remote_state" "aws_infra" {
  backend = "local"
  config = {
    path = "${path.module}/../aws/terraform.tfstate"
  }
}
```

Sau do Terraform mo tunnel:

```text
127.0.0.1:18443 -> EC2 -> $(minikube ip):8443
```

Va lay certificate Minikube qua SSH:

```text
/home/ubuntu/.minikube/profiles/minikube/client.crt
/home/ubuntu/.minikube/profiles/minikube/client.key
/home/ubuntu/.minikube/ca.crt
```

Kubernetes provider duoc cau hinh bang:

```hcl
provider "kubernetes" {
  host = data.external.minikube_api_tunnel.result.host

  client_certificate     = base64decode(data.external.minikube_cert.result.data)
  client_key             = base64decode(data.external.minikube_key.result.data)
  cluster_ca_certificate = base64decode(data.external.minikube_ca.result.data)
}
```

Day la phan "wire provider khac vao": AWS provider tao ha tang, Kubernetes provider duoc cau hinh dong dua tren output/cert cua ha tang vua tao.

### Vi sao noi Kubernetes voi ALB bang NodePort + socat

ALB forward request vao EC2 port `30080`. Kubernetes Service dung NodePort `30080`.

Voi Minikube Docker driver, NodePort nam trong mang Minikube, khong dam bao listen truc tiep tren EC2 host. Vi vay EC2 chay `socat` proxy:

```text
EC2:30080 -> $(minikube ip):30080
```

Luồng đầy đủ:

```text
ALB:80 -> EC2:30080 -> socat -> Minikube NodePort:30080 -> nginx pod:80
```

## Ghi Chu Bao Mat

- Khong commit `terraform.tfstate`, `.terraform/`, `*.tfvars`, private key `.pem`, cert `.crt`, key `.key`.
- Security Group SSH nen gioi han theo IP ca nhan thay vi mo `0.0.0.0/0`.
- Day la kien truc lab, khong phai production. Production nen dung EKS va secret management chuan hon.

