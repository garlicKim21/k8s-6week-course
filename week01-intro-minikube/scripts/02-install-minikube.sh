#!/bin/bash
# Minikube 및 kubectl 설치 스크립트
# 사용법: bash 02-install-minikube.sh

set -e

echo "=== Minikube & kubectl 설치 스크립트 ==="
echo ""

# Minikube 설치
echo "[1/3] Minikube 설치..."
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo "Minikube 버전:"
minikube version
echo ""

# kubectl 설치
echo "[2/3] kubectl 설치..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

echo "kubectl 버전:"
kubectl version --client
echo ""

# kubectl 자동완성 설정
echo "[3/3] kubectl 자동완성 설정..."
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc

echo ""
echo "=== 설치 완료 ==="
echo ""
echo "Minikube 클러스터 시작:"
echo "  minikube start --driver=docker"
echo ""
echo "자동완성 적용 (현재 세션):"
echo "  source ~/.bashrc"
