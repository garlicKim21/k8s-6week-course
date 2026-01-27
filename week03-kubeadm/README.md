# 3주차: VM 기반 Kubernetes 클러스터 구축 (Kubeadm)

## 학습 목표

- Kubernetes 배포 방식의 차이를 이해합니다.
- Kubeadm의 동작 원리를 이해합니다.
- Ubuntu 24.04 VM 3대로 실제 Kubernetes 클러스터를 구축합니다.
- Cilium CNI를 설치하여 Pod 네트워킹을 구성합니다.

---

## 1. Kubernetes 배포 방식

### 1.1 배포 도구 비교

| 도구 | 특징 | 사용 사례 |
|------|------|----------|
| **Kubeadm** | 공식 부트스트래핑 도구, 최소한의 구성 | 학습, 소규모 환경, 커스터마이징 |
| **Kubespray** | Ansible 기반 자동화 | 대규모 클러스터, IaC 환경 |
| **ClusterAPI** | 선언적 클러스터 관리 | 멀티 클러스터, GitOps |
| **관리형 서비스** | EKS, GKE, AKS 등 | 프로덕션, 운영 부담 최소화 |

### 1.2 Kubeadm이란?

Kubeadm은 Kubernetes 공식 클러스터 부트스트래핑 도구입니다.

**특징:**
- 최소한의 가동 가능한 클러스터 구성
- 클러스터 bootstrapping에만 관여 (인프라 프로비저닝 X)
- 다른 배포 도구들의 기초가 됨
- 높은 커스터마이징 가능

**Kubeadm이 하는 일:**
- 인증서 생성 및 관리
- kubeconfig 파일 생성
- Control Plane 컴포넌트 배포
- etcd 클러스터 구성
- 토큰 관리 (노드 조인)

**Kubeadm이 하지 않는 일:**
- VM/서버 프로비저닝
- Container Runtime 설치
- CNI 플러그인 설치
- 모니터링/로깅 설정

---

## 2. 실습 환경 준비

### 2.1 네트워크 구성

```
┌─────────────────────────────────────────────────┐
│                  네트워크 대역                    │
│              예: 192.168.1.0/24                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  │ Control     │  │ Worker      │  │ Worker      │
│  │ Plane       │  │ Node 1      │  │ Node 2      │
│  │             │  │             │  │             │
│  │ 192.168.1.10│  │ 192.168.1.11│  │ 192.168.1.12│
│  └─────────────┘  └─────────────┘  └─────────────┘
│                                                 │
└─────────────────────────────────────────────────┘
```

### 2.2 VM 사양

| 노드 | 역할 | CPU | RAM | Disk | IP (예시) |
|------|------|-----|-----|------|-----------|
| k8s-master | Control Plane | 2코어 | 4GB | 30GB | 192.168.1.10 |
| k8s-worker1 | Worker | 2코어 | 2GB | 20GB | 192.168.1.11 |
| k8s-worker2 | Worker | 2코어 | 2GB | 20GB | 192.168.1.12 |

> **Note**: IP 주소는 실제 환경에 맞게 변경하세요.

### 2.3 VM 생성 및 기본 설정

Ubuntu 24.04 Server를 설치한 후, 각 노드에서 다음을 확인합니다:

```bash
# OS 버전 확인
cat /etc/os-release

# 네트워크 연결 확인
ping 8.8.8.8

# 호스트명 설정 (각 노드에 맞게)
sudo hostnamectl set-hostname k8s-master  # 또는 k8s-worker1, k8s-worker2
```

---

## 3. 노드 사전 준비 (모든 노드에서 실행)

### 3.1 /etc/hosts 설정

모든 노드에서 실행:

```bash
# /etc/hosts 파일에 노드 정보 추가
sudo tee -a /etc/hosts << EOF

# Kubernetes Cluster Nodes
192.168.1.10 k8s-master
192.168.1.11 k8s-worker1
192.168.1.12 k8s-worker2
EOF
```

### 3.2 Swap 비활성화

Kubernetes는 Swap을 비활성화해야 합니다:

```bash
# Swap 즉시 비활성화
sudo swapoff -a

# 재부팅 후에도 비활성화 유지
sudo sed -i '/[[:space:]]swap[[:space:]]/ s/^/#/' /etc/fstab

# 확인
free -h
```

### 3.3 커널 모듈 로드

```bash
# 필요한 커널 모듈 설정
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# 즉시 로드
sudo modprobe overlay
sudo modprobe br_netfilter

# 확인
lsmod | grep -E "overlay|br_netfilter"
```

### 3.4 sysctl 파라미터 설정

```bash
# 네트워크 설정
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 적용
sudo sysctl --system
```

### 3.5 Containerd 설치

#### 3.5.1 바이너리 다운로드 및 설치

```bash
# 변수 설정
CONTAINERD_VERSION="2.2.1"
ARCH="amd64"

# containerd 다운로드 및 설치
cd /tmp
wget "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
sudo tar Czxvf /usr/local "containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
rm -f "containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"

# systemd 서비스 파일 설치
sudo wget -O /etc/systemd/system/containerd.service \
    https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
```

#### 3.5.2 Containerd 설정

```bash
# 설정 디렉토리 생성
sudo mkdir -p /etc/containerd

# 기본 설정 생성
sudo /usr/local/bin/containerd config default | sudo tee /etc/containerd/config.toml

# SystemdCgroup 활성화 (Kubernetes 필수)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 서비스 시작 및 활성화
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# 확인
sudo systemctl status containerd
```

#### 3.5.3 runc 설치

```bash
RUNC_VERSION="1.4.0"

cd /tmp
wget "https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64"
sudo install -m 755 runc.amd64 /usr/local/sbin/runc
rm -f runc.amd64

# 확인
runc --version
```

#### 3.5.4 CNI 플러그인 설치

```bash
CNI_PLUGINS_VERSION="1.6.1"

cd /tmp
wget "https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar Czxvf /opt/cni/bin "cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
rm -f "cni-plugins-linux-amd64-v${CNI_PLUGINS_VERSION}.tgz"
```

### 3.6 Kubernetes 도구 설치

```bash
# 필수 패키지 설치
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Kubernetes apt 저장소 키 추가
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Kubernetes 저장소 추가
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# kubeadm, kubelet, kubectl 설치
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# 버전 고정 (자동 업그레이드 방지)
sudo apt-mark hold kubelet kubeadm kubectl

# kubelet 활성화
sudo systemctl enable kubelet

# 확인
kubeadm version
kubectl version --client
```

---

## 4. Control Plane 초기화

### 4.1 kubeadm 설정 파일 작성

`configs/kubeadm-config.yaml`:
```yaml
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.1.10  # Control Plane 노드 IP
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  name: k8s-master
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: v1.35.0
networking:
  podSubnet: 10.244.0.0/16      # Pod CIDR (Cilium과 일치)
  serviceSubnet: 10.96.0.0/12   # Service CIDR
controllerManager: {}
scheduler: {}
etcd:
  local:
    dataDir: /var/lib/etcd
```

### 4.2 Control Plane 초기화

Control Plane 노드에서만 실행:

```bash
# 클러스터 초기화
sudo kubeadm init --config=kubeadm-config.yaml

# 또는 설정 파일 없이
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.1.10
```

초기화 성공 시 다음과 유사한 출력이 나타납니다:

```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.10:6443 --token abcdef.0123456789abcdef \
    --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### 4.3 kubectl 설정

```bash
# 일반 사용자로 kubectl 사용 설정
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 확인
kubectl get nodes
kubectl get pods -A
```

---

## 5. Worker Node 조인

### 5.1 조인 명령어 확인

Control Plane에서 토큰 재생성 (필요시):

```bash
# 새 토큰 생성 및 조인 명령어 출력
kubeadm token create --print-join-command
```

### 5.2 Worker Node 조인

각 Worker 노드에서 실행:

```bash
# 조인 명령어 실행 (출력된 명령어 사용)
sudo kubeadm join 192.168.1.10:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:1234567890abcdef...
```

### 5.3 노드 상태 확인

Control Plane에서:

```bash
kubectl get nodes
```

예상 출력 (CNI 설치 전):
```
NAME          STATUS     ROLES           AGE   VERSION
k8s-master    NotReady   control-plane   5m    v1.35.0
k8s-worker1   NotReady   <none>          2m    v1.35.0
k8s-worker2   NotReady   <none>          1m    v1.35.0
```

> **Note**: CNI가 설치되기 전에는 모든 노드가 `NotReady` 상태입니다.

---

## 6. Cilium CNI 설치

### 6.1 Cilium이란?

Cilium은 eBPF 기반의 고성능 CNI 플러그인입니다.

**주요 기능:**
- Pod 네트워킹
- Network Policy (L3/L4/L7)
- kube-proxy 대체 가능
- 서비스 로드밸런싱
- 관측 가능성 (Hubble)

### 6.2 Cilium CLI 설치

```bash
# Cilium CLI 설치
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz

# 확인
cilium version --client
```

### 6.3 Cilium 설치

```bash
# Cilium 설치 (기본 설정)
cilium install --version 1.18.6

# 설치 상태 확인
cilium status --wait

# 연결 테스트
cilium connectivity test
```

### 6.4 노드 상태 재확인

```bash
kubectl get nodes
```

예상 출력 (Cilium 설치 후):
```
NAME          STATUS   ROLES           AGE   VERSION
k8s-master    Ready    control-plane   10m   v1.35.0
k8s-worker1   Ready    <none>          7m    v1.35.0
k8s-worker2   Ready    <none>          6m    v1.35.0
```

### 6.5 Cilium Pod 확인

```bash
kubectl get pods -n kube-system -l k8s-app=cilium
```

---

## 7. 클러스터 검증

### 7.1 시스템 Pod 확인

```bash
kubectl get pods -A
```

모든 Pod가 `Running` 상태여야 합니다.

### 7.2 테스트 배포

```bash
# nginx 배포
kubectl create deployment nginx --image=nginx --replicas=3

# 확인
kubectl get pods -o wide

# 노드별 분산 확인
kubectl get pods -o wide | awk '{print $7}' | sort | uniq -c
```

### 7.3 정리

```bash
kubectl delete deployment nginx
```

---

## 8. 문제 해결

### 8.1 일반적인 문제

#### 노드가 NotReady 상태

```bash
# 노드 상세 정보 확인
kubectl describe node <node-name>

# kubelet 로그 확인
journalctl -u kubelet -f

# containerd 상태 확인
sudo systemctl status containerd
```

#### kubeadm init 실패

```bash
# 초기화 재시도 전 리셋
sudo kubeadm reset
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube

# 다시 시도
sudo kubeadm init ...
```

#### 토큰 만료

```bash
# 새 토큰 생성
kubeadm token create --print-join-command
```

### 8.2 유용한 디버깅 명령어

```bash
# 클러스터 상태
kubectl cluster-info
kubectl get componentstatuses

# 이벤트 확인
kubectl get events --sort-by='.lastTimestamp'

# 노드 리소스 확인
kubectl top nodes

# Pod 리소스 확인
kubectl top pods -A
```

---

## 9. 실습 정리

### 9.1 오늘 배운 내용

1. **Kubernetes 배포 방식**: Kubeadm, Kubespray, ClusterAPI 비교
2. **노드 사전 준비**: swap off, 커널 모듈, sysctl 설정
3. **Containerd 설치**: 바이너리 설치, SystemdCgroup 설정
4. **Kubeadm 클러스터**: init, join 과정
5. **Cilium CNI**: eBPF 기반 네트워킹

### 9.2 클러스터 구조 요약

```
┌──────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                  │
├──────────────────────────────────────────────────────┤
│  Control Plane (k8s-master)                          │
│  ├── kube-apiserver                                  │
│  ├── etcd                                            │
│  ├── kube-scheduler                                  │
│  ├── kube-controller-manager                         │
│  ├── kubelet                                         │
│  └── cilium-agent                                    │
├──────────────────────────────────────────────────────┤
│  Worker Nodes (k8s-worker1, k8s-worker2)             │
│  ├── kubelet                                         │
│  ├── cilium-agent                                    │
│  └── [User Pods]                                     │
└──────────────────────────────────────────────────────┘
```

### 9.3 다음 주차 예고

4주차에서는 Kubernetes 네트워킹을 심화 학습합니다.
- Service (ClusterIP, NodePort, LoadBalancer)
- DNS와 서비스 디스커버리
- 멀티 컨테이너 Pod

---

## 참고 자료

- [Kubeadm 공식 문서](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Containerd 공식 문서](https://containerd.io/docs/)
- [Cilium 공식 문서](https://docs.cilium.io/)
- [Kubernetes 버전 정책](https://kubernetes.io/releases/version-skew-policy/)
