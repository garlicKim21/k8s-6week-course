# 1주차: Kubernetes 소개 및 Minikube 환경 구성

## 학습 목표

- 컨테이너 기술의 기본 개념을 이해합니다.
- Kubernetes가 왜 필요한지, 어떤 문제를 해결하는지 이해합니다.
- Ubuntu 24.04 VM에 Minikube를 설치하고 첫 번째 클러스터를 생성합니다.
- kubectl 기본 명령어를 익힙니다.

---

## 1. 컨테이너 기술의 이해

### 1.1 컨테이너란?

컨테이너는 애플리케이션과 그 실행에 필요한 모든 것(코드, 런타임, 라이브러리, 설정)을 하나의 패키지로 묶어 **격리된 환경**에서 실행하는 기술입니다.

#### 컨테이너 vs 가상 머신

| 구분 | 컨테이너 | 가상 머신 (VM) |
|------|----------|----------------|
| 격리 수준 | 프로세스 수준 (커널 공유) | OS 수준 (커널 분리) |
| 리소스 사용 | 가볍고 빠름 | 무겁고 느림 |
| 시작 시간 | 초 단위 | 분 단위 |
| 이미지 크기 | MB 단위 | GB 단위 |

### 1.2 Linux 컨테이너 기술의 핵심

컨테이너는 Linux 커널의 다음 기능들로 구현됩니다:

#### Namespaces (격리)
프로세스가 볼 수 있는 시스템 리소스를 격리합니다.

| Namespace | 격리 대상 |
|-----------|-----------|
| PID | 프로세스 ID |
| Network | 네트워크 인터페이스, IP 주소 |
| Mount | 파일 시스템 마운트 포인트 |
| UTS | 호스트명, 도메인명 |
| IPC | 프로세스 간 통신 |
| User | 사용자/그룹 ID |

#### cgroups (Control Groups, 리소스 제한)
프로세스 그룹의 리소스 사용량을 제한합니다.

- CPU 사용량 제한
- 메모리 사용량 제한
- 디스크 I/O 제한
- 네트워크 대역폭 제한

### 1.3 Container Runtime

컨테이너 런타임은 컨테이너의 생명주기(생성, 실행, 삭제)를 관리하는 소프트웨어입니다.

#### 런타임 계층 구조

```
┌─────────────────────────────────────┐
│         High-Level Runtime          │
│    (containerd, CRI-O, Docker)      │
├─────────────────────────────────────┤
│          Low-Level Runtime          │
│              (runc)                 │
├─────────────────────────────────────┤
│           Linux Kernel              │
│    (namespaces, cgroups, etc.)      │
└─────────────────────────────────────┘
```

- **High-Level Runtime**: 이미지 관리, 네트워크 설정, 컨테이너 관리 API 제공
- **Low-Level Runtime**: Linux 커널과 직접 상호작용하여 컨테이너 프로세스 실행

#### OCI (Open Container Initiative)

컨테이너 이미지와 런타임에 대한 표준 규격입니다.
- **Image Spec**: 컨테이너 이미지 형식
- **Runtime Spec**: 컨테이너 실행 방법

#### CRI (Container Runtime Interface)

Kubernetes가 다양한 컨테이너 런타임과 통신하기 위한 표준 인터페이스입니다.

```
kubelet ──── CRI ──── containerd ──── runc
                  └── CRI-O ──────── runc
```

---

## 2. Kubernetes 개요

### 2.1 왜 Kubernetes가 필요한가?

마이크로서비스 아키텍처(MSA)의 확산으로 컨테이너 수가 급증했습니다.

**수동 관리의 문제점**:
- 수백~수천 개의 컨테이너를 어떻게 배포할 것인가?
- 컨테이너가 죽으면 어떻게 복구할 것인가?
- 트래픽이 증가하면 어떻게 확장할 것인가?
- 업데이트는 어떻게 무중단으로 할 것인가?

**Kubernetes가 해결하는 문제**:
- **자동 배포**: 선언적 설정으로 원하는 상태를 정의하면 자동으로 배포
- **자동 복구 (Self-Healing)**: 컨테이너 장애 시 자동 재시작
- **자동 스케일링**: 부하에 따라 자동으로 컨테이너 수 조절
- **롤링 업데이트**: 무중단 배포 및 롤백
- **서비스 디스커버리**: 컨테이너 간 통신을 위한 DNS 및 로드밸런싱

### 2.2 Kubernetes의 역사

- **2003~2004**: Google 내부에서 Borg 프로젝트 시작
- **2014년 6월**: Kubernetes 오픈소스로 공개
- **2015년 7월**: v1.0 첫 안정 버전 릴리즈
- **2015년**: CNCF(Cloud Native Computing Foundation)에 기부
- **현재**: 컨테이너 오케스트레이션의 사실상 표준

### 2.3 Kubernetes 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                      Control Plane                          │
├─────────────┬─────────────┬──────────────┬─────────────────┤
│ kube-api    │ etcd        │ kube-        │ kube-controller │
│ server      │             │ scheduler    │ manager         │
└─────────────┴─────────────┴──────────────┴─────────────────┘
                              │
                    ┌─────────┴─────────┐
                    ▼                   ▼
┌─────────────────────────┐  ┌─────────────────────────┐
│      Worker Node 1      │  │      Worker Node 2      │
├─────────────────────────┤  ├─────────────────────────┤
│ kubelet                 │  │ kubelet                 │
│ kube-proxy              │  │ kube-proxy              │
│ Container Runtime       │  │ Container Runtime       │
│ ┌─────┐ ┌─────┐        │  │ ┌─────┐ ┌─────┐        │
│ │ Pod │ │ Pod │        │  │ │ Pod │ │ Pod │        │
│ └─────┘ └─────┘        │  │ └─────┘ └─────┘        │
└─────────────────────────┘  └─────────────────────────┘
```

#### Control Plane 컴포넌트

| 컴포넌트 | 역할 |
|----------|------|
| **kube-apiserver** | Kubernetes API를 제공하는 중앙 관리 포인트. 모든 요청의 진입점 |
| **etcd** | 클러스터의 모든 상태 데이터를 저장하는 분산 Key-Value 저장소 |
| **kube-scheduler** | 새로운 Pod를 어떤 Node에서 실행할지 결정 |
| **kube-controller-manager** | 다양한 컨트롤러(Node, Replication, Endpoint 등)를 실행 |

#### Worker Node 컴포넌트

| 컴포넌트 | 역할 |
|----------|------|
| **kubelet** | 각 노드에서 실행되는 에이전트. Pod의 생명주기 관리 |
| **kube-proxy** | 네트워크 프록시. Service의 로드밸런싱 담당 |
| **Container Runtime** | 컨테이너 실행 (containerd, CRI-O 등) |

---

## 3. 실습 환경 구성

### 3.1 사전 준비

#### 실습 환경 요구사항

| 항목 | 요구사항 |
|------|----------|
| OS | Ubuntu 24.04 LTS Server |
| CPU | 2코어 이상 |
| RAM | 4GB 이상 |
| Disk | 20GB 이상 |
| 네트워크 | 인터넷 연결 필요 |

#### Ubuntu 24.04 VM 준비

VirtualBox, VMware, Hyper-V 또는 클라우드 VM을 사용하여 Ubuntu 24.04 Server를 설치합니다.

### 3.2 Docker 설치

Minikube는 다양한 드라이버를 지원하지만, 이 실습에서는 Docker 드라이버를 사용합니다.

#### 3.2.1 기존 Docker 패키지 제거 (있는 경우)

```bash
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg
done
```

#### 3.2.2 Docker 공식 저장소 추가

```bash
# 필수 패키지 설치
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Docker GPG 키 추가
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Docker 저장소 추가
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### 3.2.3 Docker 설치

```bash
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

#### 3.2.4 Docker 권한 설정

```bash
# 현재 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER

# 변경사항 적용 (재로그인 또는 다음 명령어 실행)
newgrp docker
```

#### 3.2.5 Docker 설치 확인

```bash
docker --version
docker run hello-world
```

### 3.3 Minikube 설치

#### 3.3.1 Minikube 바이너리 다운로드

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

#### 3.3.2 Minikube 설치 확인

```bash
minikube version
```

### 3.4 kubectl 설치

kubectl은 Kubernetes 클러스터와 상호작용하기 위한 CLI 도구입니다.

#### 3.4.1 kubectl 다운로드 및 설치

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
```

#### 3.4.2 kubectl 설치 확인

```bash
kubectl version --client
```

### 3.5 Minikube 클러스터 생성

#### 3.5.1 클러스터 시작

```bash
minikube start --driver=docker
```

예상 출력:
```
😄  minikube v1.36.0 on Ubuntu 24.04
✨  Using the docker driver based on user configuration
📌  Using Docker driver with root privileges
👍  Starting control plane node minikube in cluster minikube
🚜  Pulling base image ...
🔥  Creating docker container (CPUs=2, Memory=2200MB) ...
🐳  Preparing Kubernetes v1.35.0 on Docker ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster
```

#### 3.5.2 클러스터 상태 확인

```bash
# 클러스터 상태 확인
minikube status

# 노드 확인
kubectl get nodes

# 클러스터 정보 확인
kubectl cluster-info
```

#### 3.5.3 시스템 Pod 확인

```bash
kubectl get pods -A
```

예상 출력:
```
NAMESPACE     NAME                               READY   STATUS    RESTARTS   AGE
kube-system   coredns-xxx                        1/1     Running   0          2m
kube-system   etcd-minikube                      1/1     Running   0          2m
kube-system   kube-apiserver-minikube            1/1     Running   0          2m
kube-system   kube-controller-manager-minikube   1/1     Running   0          2m
kube-system   kube-proxy-xxx                     1/1     Running   0          2m
kube-system   kube-scheduler-minikube            1/1     Running   0          2m
kube-system   storage-provisioner                1/1     Running   0          2m
```

---

## 4. kubectl 기본 명령어

### 4.1 정보 조회 명령어

#### kubectl get
리소스 목록을 조회합니다.

```bash
# 노드 목록
kubectl get nodes

# Pod 목록 (default 네임스페이스)
kubectl get pods

# 모든 네임스페이스의 Pod
kubectl get pods -A

# 더 자세한 정보
kubectl get pods -o wide

# YAML 형식으로 출력
kubectl get pods -o yaml
```

#### kubectl describe
리소스의 상세 정보를 조회합니다.

```bash
# 노드 상세 정보
kubectl describe node minikube

# Pod 상세 정보
kubectl describe pod <pod-name>
```

#### kubectl logs
Pod의 로그를 확인합니다.

```bash
# Pod 로그 확인
kubectl logs <pod-name>

# 실시간 로그 확인
kubectl logs -f <pod-name>

# 특정 컨테이너 로그 (멀티 컨테이너 Pod)
kubectl logs <pod-name> -c <container-name>
```

### 4.2 첫 번째 Pod 실행

#### 4.2.1 nginx Pod 실행

```bash
# nginx Pod 생성
kubectl run nginx --image=nginx

# Pod 상태 확인
kubectl get pods

# Pod 상세 정보
kubectl describe pod nginx

# Pod 로그 확인
kubectl logs nginx
```

#### 4.2.2 Pod 접속

```bash
# Pod 내부 쉘 접속
kubectl exec -it nginx -- /bin/bash

# 내부에서 nginx 동작 확인
curl localhost
exit
```

#### 4.2.3 Pod 삭제

```bash
kubectl delete pod nginx
```

### 4.3 유용한 명령어

```bash
# 사용 가능한 API 리소스 목록
kubectl api-resources

# 명령어 도움말
kubectl --help
kubectl get --help

# 클러스터 이벤트 확인
kubectl get events

# 현재 컨텍스트 확인
kubectl config current-context
```

---

## 5. Minikube 관리

### 5.1 클러스터 제어

```bash
# 클러스터 중지
minikube stop

# 클러스터 시작 (기존 클러스터 재시작)
minikube start

# 클러스터 삭제
minikube delete

# 클러스터 상태 확인
minikube status
```

### 5.2 Minikube 대시보드

Kubernetes 웹 UI를 실행합니다.

```bash
minikube dashboard
```

### 5.3 SSH 접속

Minikube 노드에 직접 접속합니다.

```bash
minikube ssh
```

---

## 6. 실습 정리

### 6.1 오늘 배운 내용

1. **컨테이너 기술**: namespaces, cgroups를 통한 프로세스 격리
2. **Container Runtime**: OCI, CRI 표준과 containerd/runc 구조
3. **Kubernetes 개요**: 왜 필요한지, 어떤 문제를 해결하는지
4. **Kubernetes 아키텍처**: Control Plane과 Worker Node 컴포넌트
5. **Minikube 설치**: Ubuntu 24.04에 Docker + Minikube 환경 구성
6. **kubectl 기본**: get, describe, logs, exec 명령어

### 6.2 다음 주차 예고

2주차에서는 Kubernetes의 핵심 오브젝트인 Pod, ReplicaSet, Deployment를 배웁니다.
- YAML 파일로 리소스 정의하기
- Deployment를 통한 애플리케이션 배포
- 롤링 업데이트와 롤백
- 스케일링

---

## 참고 자료

- [Kubernetes 공식 문서 - 개념](https://kubernetes.io/ko/docs/concepts/)
- [Minikube 공식 문서](https://minikube.sigs.k8s.io/docs/)
- [Docker 공식 설치 가이드](https://docs.docker.com/engine/install/ubuntu/)
- [containerd 공식 문서](https://containerd.io/docs/)
