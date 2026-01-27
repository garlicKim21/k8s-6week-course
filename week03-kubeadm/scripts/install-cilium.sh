#!/bin/bash
#
# install-cilium.sh
# Cilium CNI 설치 스크립트
# Control Plane에서 kubeadm init 완료 후 실행
#

set -e

echo "=========================================="
echo "Cilium CNI 설치 스크립트"
echo "=========================================="

CILIUM_VERSION="1.18.6"

# 색상 출력
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "\n${GREEN}[Step]${NC} $1"
}

print_error() {
    echo -e "${RED}[Error]${NC} $1"
}

# kubectl 설정 확인
if ! kubectl get nodes &>/dev/null; then
    print_error "kubectl이 설정되지 않았습니다."
    echo "먼저 다음 명령어를 실행하세요:"
    echo "  mkdir -p \$HOME/.kube"
    echo "  sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
    echo "  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
    exit 1
fi

# Step 1: Cilium CLI 설치
print_step "Cilium CLI 설치"
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64

if [[ ! -f "/usr/local/bin/cilium" ]]; then
    cd /tmp
    curl -L --fail --remote-name-all \
        "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm -f cilium-linux-${CLI_ARCH}.tar.gz
    echo "Cilium CLI가 설치되었습니다."
else
    echo "Cilium CLI가 이미 설치되어 있습니다."
fi

echo "Cilium CLI 버전: $(cilium version --client)"

# Step 2: Cilium 설치
print_step "Cilium ${CILIUM_VERSION} 설치"
cilium install --version ${CILIUM_VERSION}

# Step 3: 설치 완료 대기
print_step "Cilium 설치 완료 대기 (최대 5분)"
cilium status --wait

echo ""
echo "=========================================="
echo -e "${GREEN}Cilium CNI 설치가 완료되었습니다!${NC}"
echo "=========================================="
echo ""
echo "노드 상태 확인:"
kubectl get nodes
echo ""
echo "Cilium Pod 상태 확인:"
kubectl get pods -n kube-system -l k8s-app=cilium
echo ""
echo "(선택) 연결 테스트 실행:"
echo "  cilium connectivity test"
echo ""
