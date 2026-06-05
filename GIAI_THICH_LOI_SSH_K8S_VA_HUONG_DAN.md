# Giai thich loi SSH EC2, loi Kubernetes va huong dan lam lai tu dau

Tai lieu nay viet cho nguoi moi, chua can biet nhieu ve AWS, Terraform hay Kubernetes.

Project nay co 2 phan rieng:

- `aws`: dung Terraform tao VPC, EC2, Security Group, ALB va cai Minikube tren EC2.
- `k8s`: dung Terraform Kubernetes provider de tao Deployment va Service trong Minikube.

Thu tu dung la:

```text
1. Chay Terraform trong thu muc aws
2. Doi EC2 cai xong Docker, kubectl, Minikube
3. SSH vao EC2 de kiem tra Minikube
4. Chay Terraform trong thu muc k8s
5. Mo ALB URL de xem nginx
```

Khong nen chay `k8s` truoc khi EC2 cai xong Minikube.

## 1. Kien truc cua bai lab

Luon hinh dung luong truy cap website nhu sau:

```text
Trinh duyet cua ban
  -> AWS ALB port 80
  -> EC2 port 30080
  -> socat proxy tren EC2
  -> Minikube IP:30080
  -> Kubernetes Service NodePort 30080
  -> Nginx Pod port 80
```

Luon hinh dung luong Terraform `k8s` ket noi vao Kubernetes API nhu sau:

```text
May local cua ban
  -> SSH tunnel 127.0.0.1:18443
  -> EC2
  -> Minikube API $(minikube ip):8443
```

Ly do can SSH tunnel: Minikube chay bang Docker driver tren EC2, nen Kubernetes API nam trong mang noi bo cua Minikube/Docker. No khong phai la dich vu public nam truc tiep tren IP public cua EC2.

## 2. Vi sao ban dau SSH vao EC2 bi loi

SSH la buoc ket noi tu may cua ban vao may ao EC2. Trong lab nay, EC2 dung Ubuntu 22.04, nen user SSH dung la:

```bash
ubuntu
```

Lenh dung khi dang o thu muc `aws`:

```bash
ssh -i ../key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
```

Thay `EC2_PUBLIC_IP` bang IP lay tu:

```bash
terraform output ec2_public_ip
```

### Nguyen nhan 1: Dung sai user SSH

Neu dung:

```bash
ssh -i ../key-pair/ec2-k8s-key.pem ec2-user@EC2_PUBLIC_IP
```

co the bi loi, vi `ec2-user` thuong dung cho Amazon Linux, khong phai Ubuntu.

Voi AMI Ubuntu trong project nay, user phai la:

```bash
ubuntu
```

### Nguyen nhan 2: Dung sai duong dan file key

File key dang nam o:

```text
key-pair/ec2-k8s-key.pem
```

Neu ban dang dung terminal tai thu muc goc project:

```bash
cd /d/terraform/lab6-4
ssh -i key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
```

Neu ban dang dung terminal tai thu muc `aws`:

```bash
cd /d/terraform/lab6-4/aws
ssh -i ../key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
```

Hai lenh khac nhau vi vi tri terminal khac nhau.

### Nguyen nhan 3: Public IP da thay doi sau khi tao lai EC2

Neu ban da `terraform destroy` roi `terraform apply` lai, EC2 moi co the co public IP moi.

Luc do IP cu khong con dung nua. Hay lay IP moi:

```bash
cd /d/terraform/lab6-4/aws
terraform output ec2_public_ip
```

Sau do SSH lai bang IP moi.

### Nguyen nhan 4: File key tren Git Bash/WSL co quyen qua rong

Neu thay loi kieu:

```text
WARNING: UNPROTECTED PRIVATE KEY FILE!
Permissions for 'ec2-k8s-key.pem' are too open.
```

thi SSH tu choi dung key vi file private key qua de doc.

Trong Git Bash hoac WSL, sua bang:

```bash
chmod 400 ../key-pair/ec2-k8s-key.pem
```

Neu dang o thu muc goc project:

```bash
chmod 400 key-pair/ec2-k8s-key.pem
```

Tren PowerShell Windows, neu `chmod` khong co tac dung, nen dung Git Bash de SSH cho don gian.

### Nguyen nhan 5: EC2 chua san sang hoac Security Group chua mo port 22

Trong project hien tai, Security Group da mo port SSH:

```hcl
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

Neu SSH ngay sau khi `terraform apply` vua xong ma bi timeout, hay doi 1-2 phut roi thu lai. EC2 can thoi gian boot xong va mo SSH service.

Kiem tra nhanh:

```bash
ssh -i ../key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
```

Neu vao duoc, nghia la phan SSH da on.

## 3. Vi sao phan Kubernetes bi loi

Phan `k8s` khong tao EC2. No chi ket noi vao Kubernetes cluster da co san tren EC2.

Trong project nay, Kubernetes cluster la Minikube. Minikube duoc cai bang file:

```text
aws/scripts/install-minikube.sh
```

Script nay duoc EC2 chay tu dong bang `user_data`.

### Nguyen nhan 1: Chay `k8s` qua som

Neu chay:

```bash
cd /d/terraform/lab6-4/k8s
terraform apply
```

truoc khi EC2 cai xong Minikube, Terraform se khong lay duoc cac file certificate:

```text
/home/ubuntu/.minikube/profiles/minikube/client.crt
/home/ubuntu/.minikube/profiles/minikube/client.key
/home/ubuntu/.minikube/ca.crt
```

Khi do Kubernetes provider khong co thong tin dang nhap vao cluster, nen bi loi.

Dung cach la SSH vao EC2 va xem log:

```bash
sudo tail -f /var/log/user-data.log
```

Chi khi thay dong nay moi chay phan `k8s`:

```text
=== HOAN THANH AUTOMATION ===
```

### Nguyen nhan 2: Tu may local goi truc tiep `https://EC2_PUBLIC_IP:8443`

Cach nay sai voi Minikube Docker driver.

Kubernetes API cua Minikube khong public truc tiep tren IP EC2. Vi vay neu cau hinh:

```hcl
host = "https://EC2_PUBLIC_IP:8443"
```

thi de gap loi timeout, connection refused hoac TLS error.

Project hien tai dung cach dung hon:

```hcl
host = data.external.minikube_api_tunnel.result.host
```

Gia tri thuc te la:

```text
https://127.0.0.1:18443
```

Day la local SSH tunnel tren may ban, sau do tunnel moi di vao Minikube API tren EC2.

### Nguyen nhan 3: May local khong co `bash`

File `k8s/provider.tf` dang dung Terraform `external` data source voi lenh:

```text
bash -c ...
```

Vi vay khi chay Terraform phan `k8s`, ban nen chay trong Git Bash hoac WSL, khong nen chay trong PowerShell thuan neu may chua co `bash`.

Neu gap loi kieu:

```text
program "bash": executable file not found
```

hay mo Git Bash roi chay lai.

### Nguyen nhan 4: Port tunnel 18443 bi chiem hoac tunnel cu bi treo

Provider mo tunnel:

```text
127.0.0.1:18443 -> EC2 -> Minikube API 8443
```

Neu co tien trinh SSH cu dang giu port 18443, Terraform co the ket noi sai tunnel hoac bi loi.

Tren Windows, co the tat cac tien trinh SSH cu:

```powershell
taskkill /F /IM ssh.exe
```

Sau do chay lai:

```bash
terraform apply
```

### Nguyen nhan 5: ALB vao EC2:30080 nhung NodePort nam trong mang Minikube

Kubernetes Service trong project:

```hcl
type      = "NodePort"
node_port = 30080
```

Nhung Minikube chay trong Docker network, nen NodePort `30080` khong chac nghe truc tiep tren EC2 public/private interface.

Vi vay script da tao systemd service:

```text
minikube-nodeport-30080.service
```

Service nay dung `socat` de forward:

```text
EC2:30080 -> $(minikube ip):30080
```

Neu service nay chua chay, ALB health check se fail va mo ALB URL se khong thay nginx.

## 4. Lam lai tu dau tung buoc

### Buoc 1: Mo Git Bash

Nen dung Git Bash de co san:

- `ssh`
- `chmod`
- `bash`
- duong dan kieu `/d/terraform/...`

### Buoc 2: Vao thu muc AWS

```bash
cd /d/terraform/lab6-4/aws
```

### Buoc 3: Kiem tra bien Terraform

Mo file:

```text
aws/terraform.tfvars
```

Hien tai dang co:

```hcl
key_name      = "ec2-k8s-key"
instance_type = "c7i-flex.large"
my_ip         = "103.156.46.146/32"
```

`key_name` phai trung voi key pair tren AWS. File private key o local la:

```text
key-pair/ec2-k8s-key.pem
```

### Buoc 4: Chay Terraform AWS

```bash
terraform init
terraform apply
```

Nhap `yes` neu Terraform hoi xac nhan.

Sau khi xong, lay IP EC2:

```bash
terraform output ec2_public_ip
```

Lay DNS cua ALB:

```bash
terraform output alb_dns_name
```

### Buoc 5: SSH vao EC2

Neu dang o thu muc `aws`, chay:

```bash
ssh -i ../key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
```

Vi du:

```bash
ssh -i ../key-pair/ec2-k8s-key.pem ubuntu@1.2.3.4
```

Neu SSH hoi:

```text
Are you sure you want to continue connecting?
```

go:

```text
yes
```

### Buoc 6: Doi EC2 cai xong Minikube

Sau khi SSH vao EC2, xem log:

```bash
sudo tail -f /var/log/user-data.log
```

Neu chua xong, tiep tuc doi.

Khi thay:

```text
=== HOAN THANH AUTOMATION ===
```

thi script cai dat da chay xong.

Thoat khoi EC2:

```bash
exit
```

### Buoc 7: Kiem tra Minikube tren EC2

SSH lai vao EC2 neu can:

```bash
ssh -i ../key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
```

Chay:

```bash
minikube status
kubectl get nodes
sudo systemctl status minikube-nodeport-30080 --no-pager
```

Ket qua mong muon:

- `minikube status` co cac thanh phan dang `Running`.
- `kubectl get nodes` thay node Minikube.
- `minikube-nodeport-30080` la `active (running)`.

### Buoc 8: Chay Terraform Kubernetes

Mo terminal local, dung Git Bash, khong chay trong SSH EC2.

Vao thu muc:

```bash
cd /d/terraform/lab6-4/k8s
```

Chay:

```bash
terraform init
terraform apply
```

Nhap `yes` neu Terraform hoi xac nhan.

Phan nay se:

- Mo SSH tunnel local `127.0.0.1:18443`.
- Lay certificate cua Minikube tu EC2.
- Tao Deployment `production-web-app`.
- Tao Service `production-web-service` NodePort `30080`.

### Buoc 9: Kiem tra app

Lay URL:

```bash
terraform output final_web_url
```

Neu output nay khong co, quay lai thu muc `aws` va lay ALB DNS:

```bash
cd /d/terraform/lab6-4/aws
terraform output alb_dns_name
```

Mo tren browser:

```text
http://ALB_DNS_NAME
```

Neu chua thay nginx ngay, doi 1-3 phut de ALB health check cap nhat.

## 5. Lenh debug quan trong

### Debug SSH

Chay verbose SSH:

```bash
ssh -v -i ../key-pair/ec2-k8s-key.pem ubuntu@EC2_PUBLIC_IP
```

Neu thay `Permission denied`, hay kiem tra:

- Dung user `ubuntu` chua.
- Dung file key chua.
- Key pair tren AWS co trung voi `key_name` khong.

Neu thay `Connection timed out`, hay kiem tra:

- IP co dung IP moi khong.
- EC2 da running chua.
- Security Group da mo port 22 chua.
- Mang cua ban co chan SSH outbound khong.

### Debug user-data tren EC2

```bash
sudo tail -n 200 /var/log/user-data.log
sudo systemctl status cloud-final --no-pager
sudo journalctl -u cloud-final -n 120 -l --no-pager
```

### Debug Minikube tren EC2

```bash
minikube status
minikube ip
kubectl get nodes
kubectl get pods -A
kubectl get svc
```

### Debug proxy NodePort tren EC2

```bash
sudo systemctl status minikube-nodeport-30080 --no-pager
curl http://localhost:30080
```

Sau khi `k8s apply` xong, `curl http://localhost:30080` nen tra ve HTML cua nginx.

### Debug Terraform k8s tren local

Neu nghi tunnel cu bi loi:

```powershell
taskkill /F /IM ssh.exe
```

Sau do trong Git Bash:

```bash
cd /d/terraform/lab6-4/k8s
terraform apply
```

## 6. Q&A

### Q1: Vi sao phai chay `aws` truoc roi moi chay `k8s`?

Vi `k8s` can co Kubernetes cluster san truoc. Cluster nam trong Minikube tren EC2. Neu EC2 chua tao xong hoac Minikube chua cai xong, `k8s` khong co noi de ket noi.

### Q2: Vi sao SSH dung user `ubuntu`, khong phai `ec2-user`?

Vi project dung AMI Ubuntu 22.04. Ubuntu AMI mac dinh dung user `ubuntu`. `ec2-user` thuong la user cua Amazon Linux.

### Q3: Vi sao khong ket noi Kubernetes API bang `https://EC2_PUBLIC_IP:8443`?

Vi Minikube Docker driver dat Kubernetes API trong mang noi bo cua Docker/Minikube. IP public cua EC2 khong tro truc tiep vao API do. Muon ket noi tu local phai dung SSH tunnel.

### Q4: SSH tunnel `127.0.0.1:18443` la gi?

Day la cong local tren may ban. Terraform Kubernetes provider ket noi vao `https://127.0.0.1:18443`, sau do SSH chuyen tiep ket noi qua EC2 toi Minikube API port `8443`.

### Q5: Vi sao ALB tro vao port `30080`?

Kubernetes Service dang dung NodePort `30080`. ALB nhan request port 80 tu internet, sau do forward vao EC2 port `30080`.

### Q6: Vi sao can `socat` proxy tren EC2?

Vi NodePort cua Minikube nam trong mang Minikube, khong chac expose truc tiep tren EC2 host. `socat` giup forward `EC2:30080` vao `$(minikube ip):30080`.

### Q7: Neu `terraform apply` trong `k8s` bao loi certificate thi lam gi?

Dau tien SSH vao EC2 va kiem tra:

```bash
minikube status
ls -l /home/ubuntu/.minikube/profiles/minikube/client.crt
ls -l /home/ubuntu/.minikube/profiles/minikube/client.key
ls -l /home/ubuntu/.minikube/ca.crt
```

Neu file chua co, user-data chua xong hoac Minikube start fail. Xem:

```bash
sudo tail -n 200 /var/log/user-data.log
```

### Q8: Neu ALB URL khong mo duoc thi kiem tra gi?

Kiem tra theo thu tu:

```bash
kubectl get pods
kubectl get svc
sudo systemctl status minikube-nodeport-30080 --no-pager
curl http://localhost:30080
```

Neu tren EC2 `curl http://localhost:30080` chua ra nginx, ALB cung se chua chay dung.

### Q9: Co can chay Terraform `k8s` trong EC2 khong?

Khong. Chay `k8s` tren may local cua ban. Provider se tu SSH vao EC2 de lay cert va mo tunnel.

### Q10: Vi sao nen dung Git Bash?

Vi provider `k8s` dung `bash -c`, SSH va mot so cu phap Linux. Git Bash tren Windows phu hop hon PowerShell thuan cho bai lab nay.

### Q11: Khi nao can `taskkill /F /IM ssh.exe`?

Khi port tunnel cu bi treo, Terraform ket noi loi, hoac nghi co SSH tunnel cu dang chiem `127.0.0.1:18443`. Lenh nay tat cac tien trinh SSH tren Windows, sau do Terraform co the tao tunnel moi.

### Q12: Neu destroy lam lai thi can nho gi?

Sau khi destroy/apply lai, EC2 public IP co the doi. Luon lay IP moi:

```bash
cd /d/terraform/lab6-4/aws
terraform output ec2_public_ip
```

Dung IP moi de SSH va de Terraform `k8s` doc remote state moi.

## 7. Tom tat ngan gon

Loi SSH ban dau thuong do dung sai user, sai duong dan key, quyen key khong dung, dung IP cu, hoac EC2 chua san sang.

Loi Kubernetes xay ra vi `k8s` phu thuoc vao Minikube tren EC2. Minikube can thoi gian cai xong, Kubernetes API khong public truc tiep qua EC2 public IP, va NodePort can proxy tu EC2 vao mang Minikube.

Quy trinh dung:

```text
terraform apply trong aws
-> lay EC2 public IP
-> SSH bang user ubuntu
-> doi /var/log/user-data.log co HOAN THANH AUTOMATION
-> kiem tra minikube status
-> terraform apply trong k8s bang Git Bash
-> mo ALB URL
```

## 8. Doi chieu voi yeu cau de bai

De bai:

```text
Dung 1 con EC2, bat minikube hoac kind trong do,
deploy mot app don gian nho nhe,
expose ra ALB.
Toan bo phai la 1-click automation tu Terraform:
bat no tu dung ha tang,
va biet wire mot provider khac vao.
```

Project hien tai dap ung cac y chinh nhu sau:

| Yeu cau | Trang thai | Bang chung trong project |
|---|---|---|
| Dung 1 EC2 | Dat | `aws/modules/compute/main.tf` co `aws_instance.k8s_node` |
| Bat Minikube hoac kind trong EC2 | Dat | `aws/scripts/install-minikube.sh` cai Docker, kubectl, Minikube |
| Deploy app don gian, nho nhe | Dat | `k8s/app-deployment.tf` dung image `nginx:alpine` |
| Expose app ra ALB | Dat | ALB port 80 forward vao EC2 port `30080`, roi EC2 proxy vao Minikube NodePort |
| Wire provider khac vao | Dat | `k8s/provider.tf` cau hinh Kubernetes provider bang IP/cert lay tu EC2 |
| 1-click automation | Dat theo huong wrapper script | `one-click-apply.sh` va `one-click-apply.ps1` tu dong chay ca 2 layer dung thu tu |

Ket luan ngan gon:

```text
Bai nay dung yeu cau ve kien truc va muc tieu.
Phan 1-click automation duoc thuc hien bang wrapper script,
trong do moi thu van do Terraform tao ra.
```

## 9. Vi sao khong nen ep thanh mot lenh `terraform apply` duy nhat

Ve ly thuyet, co the co gang nhet tat ca vao cung mot root module Terraform.
Nhung voi bai nay, cach do de loi va kho giai thich vi:

```text
Kubernetes provider can cluster song truoc
nhung cluster Minikube lai chi ton tai sau khi EC2 boot xong va user-data chay xong.
```

Terraform provider duoc cau hinh tu dau qua trinh plan/apply. Neu tai thoi diem do Minikube chua san sang, Kubernetes provider se loi vi:

- Chua co Kubernetes API de ket noi.
- Chua co file certificate cua Minikube.
- SSH vao EC2 co the chua san sang.
- `user_data` tren EC2 chay bat dong bo, Terraform tao EC2 xong khong co nghia Minikube da cai xong.

Vi vay quy trinh on dinh hon la tach thanh 2 layer:

```text
Layer 1: aws
  -> tao VPC, EC2, ALB
  -> EC2 tu cai Minikube bang user_data

Layer 2: k8s
  -> doc output cua layer aws
  -> SSH vao EC2
  -> mo tunnel vao Minikube API
  -> cau hinh Kubernetes provider
  -> deploy app
```

Wrapper script giup bien 2 layer nay thanh mot thao tac duy nhat cho nguoi dung.

## 10. Cach chay dung kieu one-click bang Git Bash

Mo Git Bash va chay:

```bash
cd /d/terraform/lab6-4
bash one-click-apply.sh
```

Script nay se tu dong lam cac viec sau:

```text
1. Vao thu muc aws
2. Chay terraform init
3. Chay terraform apply -auto-approve
4. Lay EC2 public IP va ALB DNS tu terraform output
5. Doi SSH vao EC2 duoc
6. Doi user-data cai xong Minikube
7. Kiem tra minikube status, kubectl get nodes, proxy service
8. Vao thu muc k8s
9. Chay terraform init
10. Chay terraform apply -auto-approve
11. In ra ALB URL cuoi cung
```

Neu EC2 cai Minikube cham, tang timeout:

```bash
WAIT_TIMEOUT_SECONDS=1800 bash one-click-apply.sh
```

Neu key bi loi quyen tren Git Bash, chay:

```bash
chmod 400 key-pair/ec2-k8s-key.pem
```

Sau do chay lai:

```bash
bash one-click-apply.sh
```

## 11. Cach trinh bay voi thay/co

Co the giai thich nhu sau:

```text
Em tach Terraform thanh 2 layer:

- Layer aws dung AWS provider de dung EC2, VPC, Security Group, ALB.
- EC2 tu cai Minikube bang user_data.
- Layer k8s dung Kubernetes provider de deploy app vao Minikube.
- Kubernetes provider khong hard-code kubeconfig ma duoc wire dong:
  doc EC2 public IP tu remote state cua layer aws,
  SSH vao EC2 lay certificate cua Minikube,
  mo SSH tunnel vao Kubernetes API.

De dam bao one-click automation, em viet wrapper script one-click-apply.sh.
Script nay van dung Terraform cho toan bo ha tang va app,
nhung tu dong chay dung thu tu va cho Minikube san sang truoc khi apply layer k8s.
```

Neu bi hoi "tai sao khong mot lenh terraform apply duy nhat?", tra loi:

```text
Vi Kubernetes provider can API server va certificate san sang ngay luc provider duoc cau hinh.
Trong bai nay API server va certificate chi xuat hien sau khi EC2 boot xong va user-data cai xong Minikube.
Neu ep vao mot apply duy nhat se de bi race condition.
Tach layer va dung wrapper wait readiness la cach on dinh hon va dung thuc te hon.
```
