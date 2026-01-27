# Kubernetes 6주 과정 커리큘럼

## 과정 개요

- **대상**: Kubernetes를 처음 접하는 개발자, 엔지니어, DevOps/SRE 입문자
- **기간**: 6주 (주 1회, 회당 2~3시간 예상)
- **실습 환경**:
  - 1~2주차: Minikube (Ubuntu 24.04 VM 1대)
  - 3~6주차: VM 기반 Kubernetes 클러스터 (Kubeadm, Ubuntu 24.04 VM 3대)

### 사용 버전 (2026년 1월 기준)

| 구성 요소 | 버전 | 비고 |
|-----------|------|------|
| Kubernetes | v1.35 | "Timbernetes" (2025.12 릴리즈) |
| Containerd | v2.2.1 | |
| Cilium | v1.18.6 | |
| Minikube | v1.36.0 | |
| Ubuntu | 24.04 LTS | Server |
| Docker Engine | v28.0+ | Minikube 드라이버용 |

> **Note**: 버전은 강의 시점에 따라 업데이트될 수 있습니다. 최신 버전 확인은 각 프로젝트 공식 릴리즈 페이지를 참고하세요.

---

## 주차별 커리큘럼

### 1주차: Kubernetes 소개 및 Minikube 환경 구성

**목표**: Kubernetes가 무엇인지 이해하고, Ubuntu VM에서 Minikube로 첫 클러스터를 경험

| 구분 | 내용 |
|------|------|
| 이론 | 컨테이너 기술의 이해 (Linux Container, cgroups, namespaces) |
|      | Container Runtime 개념 (Docker, Containerd, OCI, CRI) |
|      | Container Orchestration의 필요성 (MSA, 복잡도 증가) |
|      | Kubernetes 개요 및 주요 기능 (스케일링, 셀프힐링, 롤링업데이트 등) |
|      | Kubernetes 아키텍처 개요 (Control Plane / Worker Node) |
| 실습 | Ubuntu 24.04 Server VM 환경 준비 |
|      | Docker Engine 설치 |
|      | Minikube 설치 및 클러스터 생성 (--driver=docker) |
|      | kubectl 설치 및 기본 명령어 (get, describe, logs) |
|      | 첫 번째 Pod 실행 (nginx) |

**실습 환경**:
- Ubuntu 24.04 Server VM 1대
- CPU: 2코어 이상, RAM: 4GB 이상, Disk: 20GB 이상

---

### 2주차: Kubernetes 핵심 오브젝트 (1) - 워크로드

**목표**: Pod, ReplicaSet, Deployment의 개념과 동작 원리 이해

| 구분 | 내용 |
|------|------|
| 이론 | Kubernetes 주요 컴포넌트 상세 |
|      | - Control Plane: kube-apiserver, etcd, kube-scheduler, kube-controller-manager |
|      | - Worker Node: kubelet, kube-proxy, Container Runtime |
|      | Kubernetes Object 개념 (YAML 구조: apiVersion, kind, metadata, spec) |
|      | Pod 개념 및 생성 과정 |
|      | ReplicaSet과 Deployment |
|      | DaemonSet, StatefulSet 개념 소개 |
| 실습 | Pod YAML 작성 및 배포 |
|      | Deployment 생성 및 관리 |
|      | 롤링 업데이트 및 롤백 |
|      | 스케일링 (kubectl scale) |
|      | kubectl edit, apply를 통한 오브젝트 수정 |
|      | Pod 로그 및 상태 확인 |

**실습 환경**: 1주차와 동일 (Minikube)

---

### 3주차: VM 기반 Kubernetes 클러스터 구축 (Kubeadm)

**목표**: 실제 프로덕션과 유사한 멀티 노드 클러스터 구성 경험

| 구분 | 내용 |
|------|------|
| 이론 | Kubernetes 배포 방식 비교 (Kubeadm, Kubespray, ClusterAPI, 관리형 서비스) |
|      | Kubeadm 개념 및 동작 원리 |
|      | Container Runtime과 Kubernetes (CRI, Containerd) |
|      | CNI(Container Network Interface) 개념 |
|      | Cilium 소개 (eBPF 기반 네트워킹) |
| 실습 | VM 환경 준비 (3대: 1 Control Plane + 2 Worker) |
|      | 사전 준비 (swap off, 커널 모듈, sysctl 설정) |
|      | Containerd 설치 및 설정 |
|      | Kubeadm, Kubelet, Kubectl 설치 |
|      | kubeadm init으로 Control Plane 초기화 |
|      | Worker Node Join |
|      | Cilium CNI 설치 |
|      | 클러스터 상태 확인 |

**실습 환경**:
- Ubuntu 24.04 Server VM 3대
  - Control Plane: 2 CPU, 4GB RAM, 30GB Disk
  - Worker Node x2: 2 CPU, 2GB RAM, 20GB Disk
- 네트워크: VM 간 통신 가능 (같은 네트워크 대역)

---

### 4주차: Kubernetes 핵심 오브젝트 (2) - 네트워크

**목표**: Service와 Ingress를 통한 트래픽 관리 이해

| 구분 | 내용 |
|------|------|
| 이론 | Kubernetes Network Model |
|      | Pod 내 통신 vs Pod 간 통신 |
|      | Service 개념 및 타입 (ClusterIP, NodePort, LoadBalancer, ExternalName) |
|      | Endpoints와 EndpointSlices |
|      | Ingress 개념 (L7 라우팅, 호스트/경로 기반) |
|      | CoreDNS를 통한 Service Discovery |
| 실습 | 멀티 컨테이너 Pod 네트워킹 |
|      | ClusterIP Service 생성 및 테스트 |
|      | NodePort Service 생성 및 외부 접근 |
|      | Service를 통한 로드밸런싱 확인 |
|      | DNS 확인 (nslookup, /etc/resolv.conf) |
|      | (선택) Ingress Controller 설치 및 Ingress 규칙 생성 |

**실습 환경**: 3주차에서 구축한 Kubeadm 클러스터

---

### 5주차: Kubernetes 핵심 오브젝트 (3) - 스토리지

**목표**: 다양한 볼륨 유형과 영구 스토리지 관리 이해

| 구분 | 내용 |
|------|------|
| 이론 | Kubernetes Storage Model |
|      | 볼륨의 종류와 특징 |
|      | - 임시 볼륨: emptyDir |
|      | - 설정 볼륨: ConfigMap, Secret |
|      | - 호스트 볼륨: HostPath |
|      | - 영구 볼륨: PV, PVC, StorageClass |
|      | PV/PVC 라이프사이클 (프로비저닝, 바인딩, 사용, 반환) |
|      | Access Mode (RWO, ROX, RWX, RWOP) |
|      | 동적 프로비저닝과 StorageClass |
| 실습 | emptyDir을 활용한 컨테이너 간 데이터 공유 |
|      | ConfigMap 생성 및 Pod 주입 (환경변수, 볼륨) |
|      | Secret 생성 및 Pod 주입 |
|      | local-path-provisioner 구성 |
|      | PVC 생성 및 동적 프로비저닝 확인 |
|      | 데이터 영속성 테스트 (Pod 삭제 후 재생성) |

**실습 환경**: 3주차에서 구축한 Kubeadm 클러스터

---

### 6주차: 운영 및 트러블슈팅

**목표**: 실제 운영 환경에서의 디버깅 및 관리 능력 배양

| 구분 | 내용 |
|------|------|
| 이론 | Container Runtime 핸들링 (crictl) |
|      | containerd / containerd-shim / runc 관계 |
|      | 프로세스 트리 확인 (pstree, systemd-cgls, systemd-cgtop) |
|      | kube-apiserver 장애 시 대응 방법 |
|      | 주요 트러블슈팅 패턴 |
|      | 자주 사용하는 kubectl 명령어 정리 |
| 실습 | crictl로 컨테이너 상태 확인 |
|      | kubectl logs, describe를 통한 디버깅 |
|      | Pod 장애 시뮬레이션 및 복구 |
|      | Node 장애 시뮬레이션 및 Pod 재배치 확인 |
|      | kubelet 및 컨테이너 런타임 로그 분석 |
|      | (선택) etcd 백업/복구 |

**실습 환경**: 3주차에서 구축한 Kubeadm 클러스터

---

## 실습 환경 요약

### 1~2주차 (Minikube)

| 항목 | 권장 사양 |
|------|-----------|
| OS | Ubuntu 24.04 LTS Server |
| CPU | 2코어 이상 |
| RAM | 4GB 이상 |
| Disk | 20GB 이상 |
| 비고 | VM 1대 |

### 3~6주차 (Kubeadm 클러스터)

| 노드 | 수량 | CPU | RAM | Disk |
|------|------|-----|-----|------|
| Control Plane | 1대 | 2코어 | 4GB | 30GB |
| Worker Node | 2대 | 2코어 | 2GB | 20GB |

- **OS**: Ubuntu 24.04 LTS Server (모든 노드)
- **네트워크**: VM 간 통신 가능 (같은 네트워크 대역)

---

## 레포지토리 구조

```
kubernetes-study/
├── README.md                    # 메인 문서
├── week01-intro-minikube/       # 1주차: 소개 및 Minikube
├── week02-workloads/            # 2주차: 워크로드 (Pod, Deployment)
├── week03-kubeadm/              # 3주차: Kubeadm 클러스터 구축
├── week04-networking/           # 4주차: 네트워크 (Service, Ingress)
├── week05-storage/              # 5주차: 스토리지 (PV, PVC, ConfigMap)
├── week06-operations/           # 6주차: 운영 및 트러블슈팅
└── docs/
    └── reference/               # 참고 자료
```

각 주차별 디렉토리에는 다음이 포함됩니다:
- `README.md`: 해당 주차 상세 교재
- `*.yaml`: 실습용 Kubernetes 매니페스트
- `*.sh`: 실습 지원 스크립트

---

## 참고 자료

### 공식 문서
- [Kubernetes 공식 문서](https://kubernetes.io/ko/docs/)
- [Minikube 공식 문서](https://minikube.sigs.k8s.io/docs/)
- [Kubeadm 공식 문서](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Cilium 공식 문서](https://docs.cilium.io/)
- [Containerd 공식 문서](https://containerd.io/docs/)

### 추가 학습 자료
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [CNCF Landscape](https://landscape.cncf.io/)

---

## 라이선스

이 교육 자료는 누구나 학습 목적으로 자유롭게 사용할 수 있습니다.

## 기여

오류 수정, 내용 개선 제안은 언제든 환영합니다. Issue나 Pull Request를 통해 기여해주세요.
