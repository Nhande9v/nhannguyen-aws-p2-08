# Huong Dan Chay Terraform AWS + Minikube + Kubernetes

Tai lieu nay huong dan lam lai tu dau theo dung kien truc cua project hien tai:

- Thu muc `aws`: tao VPC, EC2, Security Group, ALB, Target Group.
- EC2 chay `user_data` de cai Docker, Minikube, kubectl va proxy port.
- Thu muc `k8s`: dung Terraform Kubernetes provider de tao Deployment va Service trong Minikube.

## 1. Kien Truc Dung

Luon nho luong ket noi nhu sau:

```text
Internet
  -> AWS ALB port 80
  -> EC2 port 30080
  -> socat proxy tren EC2
  -> Minikube IP:30080
  -> Kubernetes Service NodePort
  -> Nginx Pod
```

Terraform layer `k8s` khong ket noi truc tiep toi:

```text
https://EC2_PUBLIC_IP:8443
```

Vi Minikube dang chay bang Docker driver. Kubernetes API cua Minikube nam trong mang Docker/Minikube noi bo, khong phai public network cua EC2.

Vi vay phai dung SSH tunnel:

```text
May local 127.0.0.1:18443
  -> SSH tunnel qua EC2
  -> $(minikube ip):8443
```

## 2. Tai Sao Cach Cu Bi Sai

### Sai 1: Goi Kubernetes API bang EC2 public IP

Ban da dung logic:

```hcl
host = "https://EC2_PUBLIC_IP:8443"
```

Cach nay sai voi Minikube Docker driver, vi API server cua Minikube khong bind truc tiep tren public IP cua EC2.

Dung phai la:

```hcl
host = data.external.minikube_api_tunnel.result.host
```

Provider se goi vao local tunnel:

```text
https://127.0.0.1:18443
```

### Sai 2: ALB tro vao EC2:30080 nhung Minikube NodePort nam trong mang noi bo

Kubernetes Service NodePort `30080` trong Minikube Docker driver khong dam bao nghe truc tiep tren EC2 host.

Vi vay ALB vao `EC2:30080` co the fail.

Can tao proxy tren EC2:

```text
EC2:30080 -> $(minikube ip):30080
```

Project hien tai da them systemd service:

```text
minikube-nodeport-30080.service
```

Service nay dung `socat` de forward port.

### Sai 3: Chay layer `k8s` qua som

Layer `k8s` chi chay duoc sau khi EC2 cai xong Minikube.

Neu chay som, cac file sau chua ton tai:

```text
/home/ubuntu/.minikube/profiles/minikube/client.crt
/home/ubuntu/.minikube/profiles/minikube/client.key
/home/ubuntu/.minikube/ca.crt
```

Khi do Terraform provider khong lay duoc certificate va se loi.

### Sai 4: Dung `jq` tren may local

Ban gap loi:

```text
jq: command not found
```

Ly do: Terraform `external` data source chay tren may local cua ban, khong phai tren EC2. May Windows/Git Bash cua ban khong co `jq`.

Provider da duoc sua de khong can `jq`. No lay certificate bang `base64` tren EC2 roi dung `base64decode()` trong Terraform.

### Sai 5: Dung dong thoi `insecure = true` va `cluster_ca_certificate`

Ban gap loi:

```text
specifying a root certificates file with the insecure flag is not allowed
```

Ly do: Kubernetes provider khong cho vua khai bao CA cert, vua noi "bo qua verify TLS".

Da sua bang cach bo:

```hcl
insecure = true
```

Vi minh da co CA cert that cua Minikube.

## 3. Dieu Kien Truoc Khi Chay

May local can co:

- Terraform.
- Git Bash hoac bash.
- SSH client.
- File key:

```text
key-pair/ec2-k8s-key.pem
```

AWS credentials phai da cau hinh san:

```bash
aws configure
```

Hoac bien moi truong:

```bash
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_DEFAULT_REGION
```

## 4. Chay Lai Tu Dau

### Buoc 1: Vao thu muc AWS

```bash
cd /d/terraform/lab6-4/aws
```

### Buoc 2: Khoi tao Terraform neu can

```bash
terraform init
```

### Buoc 3: Apply AWS infrastructure

Neu da destroy roi, chay:

```bash
terraform apply -auto-approve
```

Lenh nay tao:

- VPC.
- Subnet.
- Security Group.
- EC2.
- ALB.
- Target Group.

Sau khi xong, lay IP EC2:

```bash
terraform output ec2_public_ip
```

Lay ALB URL:

```bash
terraform output alb_dns_name
```

## 5. Doi User-Data Cai Xong Minikube

SSH vao EC2:

```bash
ssh -i ../key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
```

Theo doi log:

```bash
sudo tail -f /var/log/user-data.log
```

Phai thay cac dong tuong tu:

```text
=== Bat dau cai Minikube ===
=== Cho apt/dpkg san sang ===
=== Cai dependencies ===
=== Cai kubectl ===
=== Cai minikube ===
=== Khoi dong Minikube ===
=== Cap quyen cert Minikube ===
=== Tao proxy EC2:30080 -> Minikube NodePort 30080 ===
=== HOAN THANH AUTOMATION ===
```

Chi khi thay:

```text
=== HOAN THANH AUTOMATION ===
```

moi duoc chay layer `k8s`.

## 6. Kiem Tra EC2 Sau Khi Cai Xong

Tren EC2, chay:

```bash
minikube status
```

Ket qua dung phai co cac thanh phan dang `Running`.

Kiem tra Kubernetes:

```bash
kubectl get nodes
```

Kiem tra proxy service:

```bash
sudo systemctl status minikube-nodeport-30080 --no-pager
```

Neu service dang `active (running)` la dung.

## 7. Chay Terraform Layer K8s

Mo terminal tren may local, khong phai tren EC2.

Vao thu muc:

```bash
cd /d/terraform/lab6-4/k8s
```

Khoi tao neu can:

```bash
terraform init
```

Apply:

```bash
terraform apply -auto-approve
```

Layer nay se:

- Mo SSH tunnel local `127.0.0.1:18443`.
- Lay cert/key/CA tu EC2.
- Tao Kubernetes Deployment.
- Tao Kubernetes Service NodePort `30080`.

## 8. Kiem Tra App

Sau khi `k8s apply` xong, lay URL:

```bash
terraform output final_web_url
```

Mo URL do tren browser.

Neu ALB chua healthy ngay, doi 1-3 phut.

## 9. Lenh Debug Quan Trong

### Kiem tra user-data

Tren EC2:

```bash
cat /var/log/user-data.log
```

Hoac:

```bash
sudo tail -n 200 /var/log/user-data.log
```

### Kiem tra cloud-init

```bash
sudo systemctl status cloud-final --no-pager
```

```bash
sudo journalctl -u cloud-final -n 120 -l --no-pager
```

### Kiem tra Minikube

```bash
minikube status
```

```bash
minikube ip
```

```bash
kubectl get pods -A
```

### Kiem tra service Kubernetes

```bash
kubectl get svc
```

Phai thay service co NodePort:

```text
30080
```

### Kiem tra proxy port 30080 tren EC2

```bash
sudo systemctl status minikube-nodeport-30080 --no-pager
```

```bash
curl http://localhost:30080
```

Neu app da deploy, lenh curl phai tra ve HTML cua nginx.

## 10. Cac Loi Thuong Gap

### Loi: `jq: command not found`

Nguyen nhan: may local khong co `jq`.

Trang thai hien tai: da sua provider de khong can `jq`.

### Loi: `connection refused`

Nguyen nhan thuong gap:

- Minikube chua chay xong.
- SSH tunnel cu bi loi.
- Port `18443` dang bi chiem.

Thu chay tren may local:

```bash
taskkill /F /IM ssh.exe
```

Sau do apply lai:

```bash
terraform apply -auto-approve
```

### Loi: `certificate signed by unknown authority`

Nguyen nhan: cert/CA lay sai hoac Minikube bi tao lai nhung tunnel/cert cu con bi cache.

Thu:

```bash
taskkill /F /IM ssh.exe
terraform apply -auto-approve
```

### Loi: `cloud-final.service failed`

Nguyen nhan: user-data tren EC2 fail.

Xem log:

```bash
sudo journalctl -u cloud-final -n 120 -l --no-pager
cat /var/log/user-data.log
```

Neu log khong co:

```text
=== HOAN THANH AUTOMATION ===
```

thi khong duoc chay layer `k8s`.

## 11. Quy Trinh Dung Can Nho

Thu tu bat buoc:

```text
1. terraform apply trong aws
2. SSH vao EC2
3. Doi user-data log co HOAN THANH AUTOMATION
4. Kiem tra minikube status
5. terraform apply trong k8s
6. Mo ALB URL
```

Khong duoc dao thu tu `aws` va `k8s`, vi `k8s` phu thuoc vao Minikube tren EC2.

## 12. Vi Sao Cach Nay Hop Ly

Minikube sinh ra de chay cluster Kubernetes nho tren mot may. Khi dung Docker driver tren EC2, no tao cluster trong Docker network. Dieu nay lam cho:

- Kubernetes API khong public truc tiep.
- NodePort khong chac expose truc tiep ra EC2 host.

Nen phai them:

- SSH tunnel cho Kubernetes provider.
- `socat` proxy cho ALB vao NodePort.

Neu muon kien truc don gian hon cho production hoac lab on dinh hon, nen dung EKS hoac k3s. Nhung neu muc tieu la tiep tuc dung Minikube, cach trong tai lieu nay la phu hop voi project hien tai.
