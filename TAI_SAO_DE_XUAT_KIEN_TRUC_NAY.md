# Tai sao de xuat kien truc EC2 + Minikube + ALB + Terraform provider wiring

Tai lieu nay giai thich ly do chon cach lam trong project, khong chi la cach chay lenh.

De bai yeu cau:

```text
Dung 1 EC2.
Bat minikube hoac kind trong EC2.
Deploy mot app don gian, nho nhe.
Expose app ra ALB.
Toan bo phai automation tu Terraform.
Biet wire mot provider khac vao.
Cach giai, kien truc, cong cu, cach wire provider, cach noi K8s voi ALB la tu nghien cuu va de xuat.
```

## 1. Muc tieu cua de bai

De bai khong chi yeu cau tao EC2. Diem quan trong hon la chung minh duoc:

- Biet dung Terraform de tao ha tang cloud.
- Biet chay mot Kubernetes cluster nho ben trong EC2 bang Minikube hoac kind.
- Biet dung provider khac ngoai AWS provider, cu the la Kubernetes provider.
- Biet lay thong tin tu ha tang vua tao de cau hinh provider tiep theo.
- Biet expose ung dung Kubernetes ra ngoai internet qua AWS ALB.

Vi vay kien truc phai the hien duoc ca 2 lop:

```text
Lop ha tang AWS
  -> VPC, subnet, security group, EC2, ALB, target group

Lop Kubernetes
  -> Minikube, Deployment, Service, NodePort
```

## 2. Vi sao chon EC2 + Minikube

De bai cho phep dung Minikube hoac kind. Project nay chon Minikube vi:

- Phu hop voi noi dung lab da thuc hanh.
- De cai tren mot EC2 duy nhat.
- Co san `kubectl`, cert va kubeconfig theo chuan Kubernetes.
- Chay duoc app nho nhu nginx.
- Du nhe cho muc tieu demo Terraform + Kubernetes provider.

Kien truc nay khong nham thay the EKS trong production. Muc tieu la lab automation:

```text
Terraform dung EC2
-> EC2 tu cai Minikube
-> Terraform wire Kubernetes provider vao Minikube
-> Terraform deploy app
```

Neu dung EKS, bai se thanh bai EKS managed Kubernetes, khong con dung tinh than "1 EC2 + minikube/kind trong do" cua de.

## 3. Vi sao dung AWS provider va Kubernetes provider

AWS provider duoc dung de tao tai nguyen AWS:

- VPC.
- Public subnet.
- Internet Gateway.
- Route table.
- Security Group.
- EC2.
- ALB.
- Target Group.
- Listener.

Kubernetes provider duoc dung de tao tai nguyen trong Kubernetes:

- Deployment.
- Service.

Day la diem "wire mot provider khac vao" cua de bai.

Neu chi dung AWS provider va viet tat ca bang shell script trong EC2, bai se khong the hien duoc kha nang wire Kubernetes provider.

Neu dung Kubernetes provider, Terraform phai biet cach ket noi vao Kubernetes API. Vi Minikube nam ben trong EC2, project phai tu dong lay:

- EC2 public IP.
- Minikube API endpoint.
- Client certificate.
- Client key.
- CA certificate.

## 4. Vi sao tach thanh 2 layer `aws` va `k8s`

Project tach thanh:

```text
aws/
  tao ha tang AWS va EC2 chay Minikube

k8s/
  wire Kubernetes provider vao Minikube va deploy app
```

Ly do tach:

```text
Kubernetes provider can cluster san sang truoc.
Nhung cluster Minikube chi xuat hien sau khi EC2 boot xong va user_data cai xong.
```

Neu ep tat ca vao mot root module va mot lan `terraform apply`, Terraform de gap van de:

- Luc provider Kubernetes duoc cau hinh, Minikube co the chua chay.
- File cert cua Minikube co the chua ton tai.
- SSH vao EC2 co the chua san sang.
- `user_data` chay bat dong bo, Terraform khong tu biet khi nao Minikube that su ready.

Vi vay tach layer giup quy trinh ro rang hon:

```text
Layer 1: AWS provider tao EC2 va ALB.
Layer 2: Kubernetes provider ket noi vao Minikube va deploy app.
```

De dat trai nghiem one-click, project dung wrapper script:

```bash
bash one-click-apply.sh
```

Script nay van dung Terraform cho toan bo ha tang va app, nhung tu dong chay dung thu tu:

```text
terraform apply trong aws
-> doi SSH
-> doi Minikube ready
-> terraform apply trong k8s
```

## 5. Vi sao wire provider bang remote state

Layer `k8s` can biet EC2 public IP va ALB DNS tu layer `aws`.

Project dung:

```hcl
data "terraform_remote_state" "aws_infra" {
  backend = "local"
  config = {
    path = "${path.module}/../aws/terraform.tfstate"
  }
}
```

Ly do:

- Khong hard-code EC2 IP.
- Neu EC2 tao lai va IP doi, layer `k8s` tu doc IP moi.
- The hien duoc cach mot Terraform layer doc output cua layer khac.
- Phu hop voi bai lab local, khong can backend phuc tap nhu S3.

Gia tri doc tu remote state:

```text
ec2_public_ip
alb_dns_name
```

Trong do `ec2_public_ip` dung de SSH vao EC2 va mo tunnel toi Minikube.

## 6. Vi sao dung SSH tunnel cho Kubernetes provider

Minikube chay bang Docker driver tren EC2. Khi do Kubernetes API cua Minikube khong phai dich vu public nam truc tiep tren:

```text
https://EC2_PUBLIC_IP:8443
```

API server nam trong mang noi bo cua Minikube/Docker. Vi vay project tao SSH tunnel:

```text
May local 127.0.0.1:18443
  -> SSH vao EC2
  -> $(minikube ip):8443
```

Terraform Kubernetes provider ket noi vao:

```text
https://127.0.0.1:18443
```

Ly do chon cach nay:

- Khong can public Kubernetes API ra internet.
- Bao mat hon viec mo API server truc tiep.
- Phu hop voi Minikube Docker driver.
- Van cho phep Terraform local dieu khien Kubernetes cluster ben trong EC2.

## 7. Vi sao lay certificate tu Minikube

Kubernetes API dung TLS va can xac thuc client.

Minikube tao san cac file:

```text
/home/ubuntu/.minikube/profiles/minikube/client.crt
/home/ubuntu/.minikube/profiles/minikube/client.key
/home/ubuntu/.minikube/ca.crt
```

Project dung SSH de doc cac file nay, encode base64, roi dua vao Kubernetes provider:

```hcl
provider "kubernetes" {
  host = data.external.minikube_api_tunnel.result.host

  client_certificate     = base64decode(data.external.minikube_cert.result.data)
  client_key             = base64decode(data.external.minikube_key.result.data)
  cluster_ca_certificate = base64decode(data.external.minikube_ca.result.data)
}
```

Ly do lam nhu vay:

- Khong can copy kubeconfig bang tay.
- Khong hard-code cert vao repo.
- Terraform tu wire provider dua tren cluster vua tao.
- Dung dung co che xac thuc TLS cua Kubernetes.

## 8. Vi sao app dung nginx alpine

App demo la:

```text
nginx:alpine
```

Ly do:

- Nho nhe.
- Khoi dong nhanh.
- Co san HTTP server port 80.
- De kiem tra bang browser hoac `curl`.
- Phu hop muc tieu de bai la app don gian.

Deployment tao 3 replicas de chung minh Kubernetes dang dieu phoi pod:

```hcl
replicas = 3
```

## 9. Vi sao expose bang NodePort 30080

ALB khong the forward truc tiep vao Kubernetes Service kieu ClusterIP, vi ALB nam o AWS layer, con Service nam trong Minikube noi bo.

Can mot port tren EC2 de ALB forward vao.

Project dung Service:

```hcl
type      = "NodePort"
node_port = 30080
```

Sau do ALB target group forward vao:

```text
EC2:30080
```

Port `30080` duoc chon vi:

- Nam trong range NodePort mac dinh cua Kubernetes: `30000-32767`.
- De nho va de debug.
- Khong trung voi port SSH 22 hay HTTP 80 tren EC2.

## 10. Vi sao can `socat` proxy giua EC2 va Minikube

Voi Minikube Docker driver, NodePort khong luon listen truc tiep tren network interface cua EC2.

Thuc te luong dung la:

```text
ALB
  -> EC2:30080
  -> socat proxy
  -> $(minikube ip):30080
  -> Kubernetes Service
  -> Pod nginx:80
```

Script `install-minikube.sh` tao systemd service:

```text
minikube-nodeport-30080.service
```

Service nay chay `socat` de forward:

```text
EC2:30080 -> MinikubeIP:30080
```

Ly do dung `socat`:

- Don gian.
- Nhe.
- De cai bang apt.
- Phu hop voi bai lab 1 EC2.
- Giai quyet dung van de ALB can mot port that tren EC2.

## 11. Vi sao ALB dung target group instance port 30080

ALB nhan request public:

```text
Internet -> ALB:80
```

Target group forward vao EC2:

```text
ALB -> EC2:30080
```

Ly do:

- ALB la entrypoint public dung yeu cau de bai.
- EC2 la noi chay Minikube.
- Port `30080` la NodePort cua Kubernetes Service.
- Security Group co the gioi han chi ALB duoc vao EC2 port `30080`.

Security Group cua EC2 mo:

```hcl
ingress {
  from_port       = 30080
  to_port         = 30080
  protocol        = "tcp"
  security_groups = [aws_security_group.alb_sg.id]
}
```

Nghia la nguoi dung internet khong vao truc tiep `EC2:30080`; chi ALB duoc forward vao port nay.

## 12. Vi sao day la de xuat hop ly cho bai lab

Kien truc nay phu hop vi:

- Dung dung rang buoc "1 EC2".
- Dung Minikube nhu lab da hoc.
- Co app nho nhe de demo.
- Co ALB public dung yeu cau.
- Co Terraform AWS provider tao cloud resource.
- Co Terraform Kubernetes provider tao Kubernetes resource.
- Co co che wire provider dong bang remote state, SSH tunnel va cert.
- Co wrapper script de nguoi dung chay mot lenh.

Day khong phai kien truc production. Neu production nen dung:

- EKS thay vi Minikube.
- Ingress Controller hoac AWS Load Balancer Controller.
- Remote backend S3 + DynamoDB lock.
- Secret management dung chuan hon.
- Security Group han che SSH theo IP ca nhan.

Nhung voi de bai lab, muc tieu la the hien kha nang tu nghien cuu cach noi AWS va Kubernetes bang Terraform. Kien truc hien tai vua du gon, vua the hien dung cac diem can hoc.

## 13. Cach noi ngan gon khi bao ve bai

Co the trinh bay:

```text
Em de xuat kien truc 2 layer.

Layer AWS dung Terraform AWS provider de tao VPC, EC2, Security Group, ALB va Target Group.
EC2 dung user_data de tu cai Docker, kubectl va Minikube.

Sau khi Minikube san sang, layer K8s dung Terraform Kubernetes provider de deploy nginx.
Kubernetes provider khong dung cau hinh thu cong ma duoc wire dong:
doc EC2 public IP tu Terraform remote state,
SSH vao EC2 lay certificate cua Minikube,
mo SSH tunnel vao Minikube API,
roi dung cert de authenticate.

App duoc expose bang Service NodePort 30080.
Vi Minikube chay trong Docker network, EC2 chay socat proxy de forward EC2:30080 vao MinikubeIP:30080.
ALB public port 80 forward vao EC2:30080, tu do request di toi nginx pod.

De dam bao one-click automation, em dung script one-click-apply.sh.
Script nay van dung Terraform de tao toan bo ha tang va app,
nhung tu dong cho EC2/Minikube ready truoc khi apply Kubernetes layer.
```

