#!/bin/bash
#
# prepare-node.sh
# Kubernetes 노드 준비 스크립트 (모든 노드에서 실행)
# Ubuntu 24.04 + Containerd 2.2.1 + Kubernetes 1.35
#

set -e

echo "=========================================="
echo "Kubernetes 노드 준비 스크립트 시작"
echo "=========================================="

# 변수 설정
CONTAINERD_VERSION="2.2.1"
RUNC_VERSION="1.4.0"
CNI_PLUGINS_VERSION="1.6.1"
KUBERNETES_VERSION="1.35"
ARCH="amd64"

# 색상 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "\n${GREEN}[Step]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[Warning]${NC} $1"
}

print_error() {
    echo -e "${RED}[Error]${NC} $1"
}

# Root 권한 확인
if [[ $EUID -ne 0 ]]; then
   print_error "이 스크립트는 root 권한이 필요합니다. sudo를 사용해주세요."
   exit 1
fi

# OS 확인
if ! grep -q "Ubuntu 24.04" /etc/os-release 2>/dev/null; then
    print_warn "Ubuntu 24.04가 아닙니다. 계속하시겠습니까? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 1: Swap 비활성화
print_step "Swap 비활성화"
swapoff -a
sed -i '/[[:space:]]swap[[:space:]]/ s/^/#/' /etc/fstab
echo "Swap이 비활성화되었습니다."

# Step 2: 커널 모듈 설정
print_step "커널 모듈 설정"
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
echo "커널 모듈이 로드되었습니다."

# Step 3: sysctl 파라미터 설정
print_step "sysctl 파라미터 설정"
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
echo "네트워크 파라미터가 설정되었습니다."

# Step 4: containerd 설치
print_step "Containerd ${CONTAINERD_VERSION} 설치"
cd /tmp

if [[ ! -f "/usr/local/bin/containerd" ]]; then
    wget -q "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
    tar Czxvf /usr/local "containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
    rm -f "containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
    echo "containerd가 설치되었습니다."
else
    echo "containerd가 이미 설치되어 있습니다."
fi

# systemd 서비스 파일 설치
if [[ ! -f "/etc/systemd/system/containerd.service" ]]; then
    wget -q -O /etc/systemd/system/containerd.service \
        https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
fi

# Step 5: containerd 설정
print_step "Containerd 설정"
mkdir -p /etc/containerd
/usr/local/bin/containerd config default > /etc/containerd/config.toml

# SystemdCgroup 활성화
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl daemon-reload
systemctl enable --now containerd
echo "containerd가 설정되었습니다."

# Step 6: runc 설치
print_step "runc ${RUNC_VERSION} 설치"
cd /tmp

if [[ ! -f "/usr/local/sbin/runc" ]]; then
    wget -q "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
    install -m 755 runc.amd64 /usr/local/sbin/runc
    rm -f runc.amd64
    echo "runc가 설치되었습니다."
else
    echo "runc가 이미 설치되어 있습니다."
fi

# Step 7: CNI 플러그인 설치
print_step "CNI 플러그인 ${CNI_PLUGINS_VERSION} 설치"
cd /tmp

if [[ ! -d "/opt/cni/bin" ]] || [[ -z "$(ls -A /opt/cni/bin 2>/dev/null)" ]]; then
    wget -q "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
    mkdir -p /opt/cni/bin
    tar Czxvf /opt/cni/bin "cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
    rm -f "cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
    echo "CNI 플러그인이 설치되었습니다."
else
    echo "CNI 플러그인이 이미 설치되어 있습니다."
fi

# Step 8: Kubernetes 도구 설치
print_step "Kubernetes ${KUBERNETES_VERSION} 도구 설치 (kubeadm, kubelet, kubectl)"
apt-get update -qq
apt-get install -y apt-transport-https ca-certificates curl gpg

# Kubernetes apt 저장소 키 추가
mkdir -p /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Kubernetes 저장소 추가
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VERSION}/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

# kubeadm, kubelet, kubectl 설치
apt-get update -qq
apt-get install -y kubelet kubeadm kubectl

# 버전 고정
apt-mark hold kubelet kubeadm kubectl

# kubelet 활성화
systemctl enable kubelet

echo ""
echo "=========================================="
echo -e "${GREEN}노드 준비가 완료되었습니다!${NC}"
echo "=========================================="
echo ""
echo "설치된 버전:"
echo "  - containerd: $(/usr/local/bin/containerd --version)"
echo "  - runc: $(runc --version | head -1)"
echo "  - kubeadm: $(kubeadm version -o short)"
echo "  - kubectl: $(kubectl version --client -o yaml | grep gitVersion | awk '{print $2}')"
echo ""
echo "다음 단계:"
echo "  - Control Plane: sudo kubeadm init --config=kubeadm-config.yaml"
echo "  - Worker Node:   sudo kubeadm join ..."
echo ""
