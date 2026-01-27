# Kubernetes 6주 완성: 입문부터 운영까지

Kubernetes를 처음 접하는 분들을 위한 체계적인 실습 중심 학습 자료입니다.

Minikube로 기초를 다진 후, Kubeadm으로 실제 멀티 노드 클러스터를 직접 구축합니다. 단순한 개념 학습을 넘어 프로덕션 수준의 환경을 경험하며 Kubernetes의 핵심을 익힙니다.

## 과정 개요

| 항목 | 내용 |
|------|------|
| 대상 | Kubernetes 입문자 ~ 초급 (개발자, 엔지니어, DevOps/SRE) |
| 기간 | 6주 (주 1회, 2~3시간) |
| 실습 환경 | Ubuntu 24.04 Server VM |
| 사전 지식 | Linux 기본 명령어, 컨테이너 기초 개념 |

### 사용 버전

| 구성 요소 | 버전 |
|-----------|------|
| Kubernetes | v1.35 |
| Containerd | v2.2.1 |
| Cilium | v1.18.6 |
| Minikube | v1.37.0 |
| Ubuntu | 24.04 LTS |

---

## 커리큘럼

### 1주차: Kubernetes 소개 및 Minikube 환경 구성
> Kubernetes가 무엇인지 이해하고, Minikube로 첫 클러스터를 경험합니다.

- 컨테이너 기술의 이해 (Linux Container, cgroups, namespaces)
- Container Runtime 개념 (Docker, Containerd, OCI, CRI)
- Kubernetes 개요 및 아키텍처
- **실습**: Ubuntu VM에 Minikube 설치, 첫 Pod 실행

[1주차 교재 바로가기](./week01-intro-minikube/)

### 2주차: Kubernetes 핵심 오브젝트 (1) - 워크로드
> Pod, ReplicaSet, Deployment의 개념과 동작 원리를 이해합니다.

- Kubernetes 주요 컴포넌트 (Control Plane, Worker Node)
- Kubernetes Object 개념 (YAML 구조)
- Pod, ReplicaSet, Deployment
- **실습**: Deployment 생성, 롤링 업데이트, 스케일링

[2주차 교재 바로가기](./week02-workloads/)

### 3주차: VM 기반 Kubernetes 클러스터 구축 (Kubeadm)
> 실제 프로덕션과 유사한 멀티 노드 클러스터를 직접 구성합니다.

- Kubernetes 배포 방식 비교 (Kubeadm, Kubespray, ClusterAPI)
- Container Runtime과 CNI 개념
- **실습**: VM 3대로 Kubeadm 클러스터 구축, Cilium CNI 설치

[3주차 교재 바로가기](./week03-kubeadm/)

### 4주차: Kubernetes 핵심 오브젝트 (2) - 네트워크
> Service와 Ingress를 통한 트래픽 관리를 이해합니다.

- Kubernetes Network Model
- Service 타입 (ClusterIP, NodePort, LoadBalancer)
- CoreDNS를 통한 Service Discovery
- **실습**: Service 생성, 로드밸런싱 확인, DNS 테스트

[4주차 교재 바로가기](./week04-networking/)

### 5주차: Kubernetes 핵심 오브젝트 (3) - 스토리지
> 다양한 볼륨 유형과 영구 스토리지 관리를 이해합니다.

- Kubernetes Storage Model
- 볼륨 종류: emptyDir, ConfigMap, Secret, PV/PVC
- 동적 프로비저닝과 StorageClass
- **실습**: ConfigMap/Secret 사용, PVC로 데이터 영속성 확인

[5주차 교재 바로가기](./week05-storage/)

### 6주차: 운영 및 트러블슈팅
> 실제 운영 환경에서의 디버깅 및 관리 능력을 배양합니다.

- Container Runtime 핸들링 (crictl)
- containerd / containerd-shim / runc 관계
- 주요 트러블슈팅 패턴
- **실습**: crictl 사용, 로그 분석, 장애 시뮬레이션

[6주차 교재 바로가기](./week06-operations/)

---

## 실습 환경

### 1~2주차: Minikube 환경

| 항목 | 권장 사양 |
|------|-----------|
| VM | 1대 |
| OS | Ubuntu 24.04 LTS Server |
| CPU | 2코어 이상 |
| RAM | 4GB 이상 |
| Disk | 20GB 이상 |

### 3~6주차: Kubeadm 클러스터

| 노드 | 수량 | CPU | RAM | Disk |
|------|------|-----|-----|------|
| Control Plane | 1대 | 2코어 | 4GB | 30GB |
| Worker Node | 2대 | 2코어 | 2GB | 20GB |

- **OS**: Ubuntu 24.04 LTS Server (모든 노드)
- **네트워크**: VM 간 통신 가능한 동일 네트워크 대역

---

## 레포지토리 구조

```
k8s-6week-course/
├── README.md                      # 이 파일
├── versions.yaml                  # 버전 정보 중앙 관리
├── week01-intro-minikube/         # 1주차: 소개 및 Minikube
│   ├── README.md
│   └── scripts/
├── week02-workloads/              # 2주차: 워크로드
│   ├── README.md
│   └── examples/
├── week03-kubeadm/                # 3주차: Kubeadm 클러스터 구축
│   ├── README.md
│   ├── scripts/
│   └── configs/
├── week04-networking/             # 4주차: 네트워크
│   ├── README.md
│   └── examples/
├── week05-storage/                # 5주차: 스토리지
│   ├── README.md
│   └── examples/
├── week06-operations/             # 6주차: 운영 및 트러블슈팅
│   ├── README.md
│   └── examples/
└── scripts/                       # 프로젝트 관리 스크립트
    └── README.md
```

---

## 빠른 시작

### 1주차 실습 시작하기

```bash
# 레포지토리 클론
git clone https://github.com/garlicKim21/k8s-6week-course.git
cd k8s-6week-course

# 1주차 교재로 이동
cd week01-intro-minikube

# README.md를 따라 실습 진행
```

---

## 참고 자료

### 공식 문서
- [Kubernetes 공식 문서](https://kubernetes.io/ko/docs/)
- [Minikube 공식 문서](https://minikube.sigs.k8s.io/docs/)
- [Kubeadm 공식 문서](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)
- [Cilium 공식 문서](https://docs.cilium.io/)
- [Containerd 공식 문서](https://containerd.io/docs/)

### 추가 학습
- [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [CNCF Landscape](https://landscape.cncf.io/)

---

## 기여

오류 수정, 내용 개선 제안은 언제든 환영합니다.
- Issue: 질문, 버그 리포트, 개선 제안
- Pull Request: 직접 수정 기여

## 라이선스

이 교육 자료는 학습 목적으로 자유롭게 사용할 수 있습니다.
