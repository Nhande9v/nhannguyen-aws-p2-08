#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Bat dau cai Minikube ==="
export DEBIAN_FRONTEND=noninteractive

echo "=== Cho apt/dpkg san sang ==="
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    sleep 5
done

echo "=== Cai dependencies ==="
for i in 1 2 3 4 5; do
    apt-get update -y && break
    sleep 10
done

apt-get install -y docker.io curl conntrack socat
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu || true

echo "=== Cai kubectl ==="
curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -m 0755 /tmp/kubectl /usr/local/bin/kubectl

echo "=== Cai minikube ==="
curl -fsSLo /tmp/minikube-linux-amd64 https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install -m 0755 /tmp/minikube-linux-amd64 /usr/local/bin/minikube

echo "=== Khoi dong Minikube ==="
sudo -u ubuntu -H minikube start --driver=docker --memory=2200mb --cpus=2

echo "=== Cap quyen cert Minikube ==="
chown -R ubuntu:ubuntu /home/ubuntu/.minikube
chmod 644 /home/ubuntu/.minikube/profiles/minikube/client.crt 2>/dev/null || true
chmod 644 /home/ubuntu/.minikube/profiles/minikube/client.key 2>/dev/null || true
chmod 644 /home/ubuntu/.minikube/ca.crt 2>/dev/null || true

echo "=== Tao proxy EC2:30080 -> Minikube NodePort 30080 ==="
cat >/usr/local/bin/minikube-nodeport-proxy.sh <<'EOF'
#!/bin/bash
set -euo pipefail

MINIKUBE_IP="$(sudo -u ubuntu -H minikube ip)"
exec /usr/bin/socat TCP-LISTEN:30080,fork,reuseaddr TCP:"${MINIKUBE_IP}":30080
EOF

chmod +x /usr/local/bin/minikube-nodeport-proxy.sh

cat >/etc/systemd/system/minikube-nodeport-30080.service <<'EOF'
[Unit]
Description=Forward EC2 port 30080 to Minikube NodePort 30080
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/local/bin/minikube-nodeport-proxy.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now minikube-nodeport-30080.service

echo "=== HOAN THANH AUTOMATION ==="
