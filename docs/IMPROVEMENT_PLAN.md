# Kubernetes 교육 자료 개선 방안

## 개선 배경

기존 교육 자료는 사내 교육용으로 제작되었으며, 다음과 같은 한계가 있었습니다:

1. **대상 제한**: 사내 직원 대상으로 제작되어 일반 입문자에게 적합하지 않음
2. **순서 문제**: Kubeadm부터 시작하여 입문자가 바로 복잡한 설정을 다뤄야 함
3. **교재 형태**: PPT 기반으로 레포지토리만으로 학습이 어려움
4. **버전 노후화**: Kubernetes 1.34, Ubuntu 22.04 등 구버전 기준
5. **구조**: 4주 과정으로 내용이 압축되어 있음

## 개선 목표

1. **일반 입문자 대상**: 누구나 접근할 수 있는 오픈 교육 자료
2. **점진적 학습**: Minikube → Kubeadm 순서로 난이도 점진적 상승
3. **레포 기반 교재**: PPT 없이 마크다운 문서만으로 완결성 있는 교재
4. **최신 버전**: Kubernetes 1.32+, Ubuntu 24.04 기준
5. **확장된 커리큘럼**: 6주 과정으로 충분한 학습 시간 확보

---

## 디렉토리 구조 변경

### 현재 구조 (AS-IS)

```
miribit-k8s-study/
├── 01-kubeadm/
├── 02-kubespray/
├── 03-container-runtime/
├── 04-kubernetes-network/
├── 05-kubernetes-storage/
├── docs/reference/
│   ├── kubernetes-study.pptx
│   ├── minikube-study.pptx
│   └── kubernetes_curriculum.md
└── README.md
```

### 변경 구조 (TO-BE)

```
kubernetes-study/
├── README.md                      # 프로젝트 소개 및 사용 가이드
├── week01-intro-minikube/         # 1주차: Kubernetes 소개 및 Minikube
│   ├── README.md                  # 1주차 교재
│   ├── 01-install-docker.sh       # Docker 설치 스크립트
│   ├── 02-install-minikube.sh     # Minikube 설치 스크립트
│   └── examples/
│       └── nginx-pod.yaml
├── week02-workloads/              # 2주차: 워크로드
│   ├── README.md                  # 2주차 교재
│   └── examples/
│       ├── pod.yaml
│       ├── replicaset.yaml
│       └── deployment.yaml
├── week03-kubeadm/                # 3주차: Kubeadm 클러스터 구축
│   ├── README.md                  # 3주차 교재
│   ├── scripts/
│   │   ├── prepare-node.sh
│   │   └── install-cilium.sh
│   └── configs/
│       └── kubeadm-config.yaml
├── week04-networking/             # 4주차: 네트워크
│   ├── README.md                  # 4주차 교재
│   └── examples/
│       ├── multi-container-pod.yaml
│       ├── clusterip-service.yaml
│       └── nodeport-service.yaml
├── week05-storage/                # 5주차: 스토리지
│   ├── README.md                  # 5주차 교재
│   └── examples/
│       ├── emptydir.yaml
│       ├── configmap.yaml
│       ├── secret.yaml
│       └── pvc.yaml
├── week06-operations/             # 6주차: 운영 및 트러블슈팅
│   ├── README.md                  # 6주차 교재
│   └── scripts/
│       └── troubleshooting-commands.sh
└── docs/
    ├── IMPROVEMENT_PLAN.md        # 이 문서
    └── reference/
        ├── kubernetes_curriculum.md
        └── (pptx 파일은 .gitignore로 제외)
```

---

## 주차별 개선 상세

### 1주차: Kubernetes 소개 및 Minikube 환경 구성

**신규 작성 필요**

| 항목 | 내용 |
|------|------|
| 교재 | week01-intro-minikube/README.md |
| 이론 | 컨테이너 개념, Kubernetes 소개, 아키텍처 개요 |
| 실습 | Ubuntu 24.04 VM 준비 → Docker 설치 → Minikube 설치 → 첫 Pod 실행 |
| 스크립트 | Docker 설치, Minikube 설치 스크립트 |
| 참고 자료 | minikube-study.pptx 내용 활용 |

### 2주차: Kubernetes 핵심 오브젝트 (1) - 워크로드

**신규 작성 필요**

| 항목 | 내용 |
|------|------|
| 교재 | week02-workloads/README.md |
| 이론 | Kubernetes 컴포넌트 상세, Pod/ReplicaSet/Deployment |
| 실습 | YAML 작성, 배포, 롤링업데이트, 스케일링 |
| 예제 | pod.yaml, replicaset.yaml, deployment.yaml |
| 참고 자료 | kubernetes-study.pptx 슬라이드 26-33, minikube-study.pptx Chapter 2 |

### 3주차: VM 기반 Kubernetes 클러스터 구축 (Kubeadm)

**기존 01-kubeadm 디렉토리 마이그레이션 + 업데이트**

| 항목 | 내용 |
|------|------|
| 교재 | week03-kubeadm/README.md |
| 이론 | 배포 방식 비교, Kubeadm 원리, CNI 개념 |
| 실습 | VM 3대 준비 → 노드 사전 준비 → kubeadm init → join → Cilium 설치 |
| 스크립트 | prepare-node.sh (Ubuntu 24.04 대응), install-cilium.sh |
| 변경 사항 | - Rocky Linux → Ubuntu 24.04<br>- Kubernetes 1.34 → 1.32<br>- Containerd 2.2.0 → 2.0.1<br>- Cilium 버전 업데이트 |
| 참고 자료 | 기존 01-kubeadm/, kubernetes-study.pptx 슬라이드 50-59 |

### 4주차: Kubernetes 핵심 오브젝트 (2) - 네트워크

**기존 04-kubernetes-network 마이그레이션 + 교재 추가**

| 항목 | 내용 |
|------|------|
| 교재 | week04-networking/README.md |
| 이론 | Network Model, Service 타입, CoreDNS |
| 실습 | Service 생성 (ClusterIP/NodePort), 로드밸런싱 확인, DNS 테스트 |
| 예제 | 기존 YAML 활용 + 정리 |
| 참고 자료 | 기존 04-kubernetes-network/, kubernetes-study.pptx 슬라이드 80-95 |

### 5주차: Kubernetes 핵심 오브젝트 (3) - 스토리지

**기존 05-kubernetes-storage 마이그레이션 + 교재 추가**

| 항목 | 내용 |
|------|------|
| 교재 | week05-storage/README.md |
| 이론 | Storage Model, Volume 종류, PV/PVC 라이프사이클 |
| 실습 | emptyDir, ConfigMap, Secret, PVC 실습 |
| 예제 | 기존 YAML 활용 + 정리 |
| 참고 자료 | 기존 05-kubernetes-storage/, kubernetes-study.pptx 슬라이드 96-112 |

### 6주차: 운영 및 트러블슈팅

**기존 03-container-runtime 확장 + 신규 내용 추가**

| 항목 | 내용 |
|------|------|
| 교재 | week06-operations/README.md |
| 이론 | Container Runtime 핸들링, 트러블슈팅 패턴 |
| 실습 | crictl 사용, 로그 분석, 장애 시뮬레이션 |
| 스크립트 | 주요 트러블슈팅 명령어 모음 |
| 참고 자료 | 기존 03-container-runtime/, kubernetes-study.pptx 슬라이드 66-79 |

---

## 작업 우선순위

### Phase 1: 기반 작업 (필수)
- [x] 커리큘럼 업데이트 (kubernetes_curriculum.md)
- [x] 개선 방안 명세 작성 (IMPROVEMENT_PLAN.md)
- [x] .gitignore에 pptx 추가
- [ ] README.md 전면 개편

### Phase 2: 1~2주차 콘텐츠 (Minikube)
- [ ] week01-intro-minikube/ 디렉토리 및 교재 작성
- [ ] week02-workloads/ 디렉토리 및 교재 작성

### Phase 3: 3주차 콘텐츠 (Kubeadm)
- [ ] week03-kubeadm/ 디렉토리 구성
- [ ] 기존 01-kubeadm/ 내용 마이그레이션
- [ ] Ubuntu 24.04 대응 스크립트 업데이트
- [ ] 교재 작성

### Phase 4: 4~6주차 콘텐츠
- [ ] week04-networking/ 구성 및 교재 작성
- [ ] week05-storage/ 구성 및 교재 작성
- [ ] week06-operations/ 구성 및 교재 작성

### Phase 5: 정리
- [ ] 기존 디렉토리 정리 (01-kubeadm, 02-kubespray 등)
- [ ] 전체 문서 검토 및 링크 확인

---

## 참고 사항

### PPT 자료 활용

기존 PPT 자료(kubernetes-study.pptx, minikube-study.pptx)는 내용 참고용으로만 사용하며, 레포지토리에서는 제외합니다. 핵심 내용은 마크다운 교재로 재작성합니다.

### 버전 관리

교육 자료의 소프트웨어 버전은 `docs/reference/kubernetes_curriculum.md`의 "사용 버전" 섹션에서 중앙 관리합니다. 각 주차별 README에서는 이를 참조하도록 합니다.

### 기여 가이드

오픈 교육 자료로 전환하므로, Issue와 Pull Request를 통한 커뮤니티 기여를 환영합니다.
