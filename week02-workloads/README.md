# 2주차: Kubernetes 핵심 오브젝트 (1) - 워크로드

## 학습 목표

- Kubernetes의 주요 컴포넌트를 상세히 이해합니다.
- Kubernetes Object의 개념과 YAML 구조를 익힙니다.
- Pod, ReplicaSet, Deployment의 관계와 동작 원리를 이해합니다.
- 실제로 애플리케이션을 배포하고 관리해봅니다.

---

## 1. Kubernetes 컴포넌트 상세

### 1.1 Control Plane 컴포넌트

Control Plane은 클러스터의 전체 상태를 관리하고 의사결정을 담당합니다.

#### kube-apiserver

- Kubernetes API를 노출하는 컴포넌트
- 모든 요청(kubectl, 다른 컴포넌트)의 진입점
- 인증, 인가, Admission Control 수행
- etcd와 직접 통신하는 유일한 컴포넌트

```
사용자/kubectl ──▶ kube-apiserver ──▶ etcd
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   scheduler    controller-manager   kubelet
```

#### etcd

- 분산 Key-Value 저장소
- 클러스터의 모든 상태 데이터 저장
  - Node 정보
  - Pod 정보
  - ConfigMap, Secret
  - 사용자 정의 리소스
- 고가용성을 위해 보통 3대 이상으로 구성

#### kube-scheduler

- 새로운 Pod를 어떤 Node에서 실행할지 결정
- 스케줄링 고려 요소:
  - 리소스 요구사항 (CPU, Memory)
  - 하드웨어/소프트웨어 제약
  - Affinity/Anti-affinity 규칙
  - Taint/Toleration
  - 데이터 지역성

#### kube-controller-manager

여러 컨트롤러를 실행하는 단일 바이너리:

| 컨트롤러 | 역할 |
|----------|------|
| Node Controller | Node 상태 모니터링, 장애 감지 |
| Replication Controller | Pod 복제본 수 유지 |
| Endpoints Controller | Service와 Pod 연결 |
| ServiceAccount Controller | 기본 ServiceAccount 생성 |
| Namespace Controller | Namespace 리소스 관리 |

### 1.2 Worker Node 컴포넌트

Worker Node는 실제 애플리케이션(Pod)이 실행되는 곳입니다.

#### kubelet

- 각 Node에서 실행되는 에이전트
- Pod의 생명주기 관리
- 주요 역할:
  - PodSpec에 따라 컨테이너 실행
  - 컨테이너 헬스체크
  - Node 및 Pod 상태 보고
  - 볼륨 마운트

```
kube-apiserver
      │
      │ watch (PodSpec)
      ▼
   kubelet ───▶ Container Runtime (containerd)
      │                │
      │                ▼
      │         ┌──────────────┐
      │         │  Container   │
      │         └──────────────┘
      │
      └───▶ 상태 보고
```

#### kube-proxy

- 네트워크 프록시 및 로드밸런서
- Service의 가상 IP(ClusterIP) 구현
- 모드:
  - iptables (기본)
  - IPVS (대규모 클러스터)
  - eBPF (Cilium 사용 시)

---

## 2. Kubernetes Object

### 2.1 Object란?

Kubernetes Object는 클러스터의 상태를 나타내는 영속적인 엔티티입니다.

**Object가 표현하는 것:**
- 어떤 컨테이너화된 애플리케이션이 어디서 실행 중인지
- 해당 애플리케이션이 사용할 수 있는 리소스
- 재시작, 업그레이드, 장애 허용 등의 정책

### 2.2 YAML 파일 구조

모든 Kubernetes Object는 다음 필수 필드를 가집니다:

```yaml
apiVersion: v1          # API 버전
kind: Pod               # Object 종류
metadata:               # 메타데이터
  name: my-pod          # Object 이름 (필수)
  namespace: default    # 네임스페이스
  labels:               # 레이블 (키-값 쌍)
    app: my-app
spec:                   # 원하는 상태 (Specification)
  # Object 종류에 따라 다름
```

#### 주요 필드 설명

| 필드 | 설명 |
|------|------|
| `apiVersion` | 사용할 Kubernetes API 버전 |
| `kind` | 생성할 Object 종류 (Pod, Deployment 등) |
| `metadata` | 이름, 레이블, 어노테이션 등 |
| `spec` | 원하는 상태 정의 |
| `status` | 현재 상태 (Kubernetes가 관리, 사용자가 작성하지 않음) |

### 2.3 선언적(Declarative) 관리

Kubernetes는 **선언적** 방식으로 동작합니다.

- **명령적**: "nginx 컨테이너를 3개 실행해"
- **선언적**: "nginx 컨테이너가 3개 실행되는 상태가 되어야 해"

```yaml
# 선언적 정의: "항상 3개의 replica가 있어야 함"
spec:
  replicas: 3
```

Kubernetes는 현재 상태(status)와 원하는 상태(spec)를 비교하여 차이를 줄이는 방향으로 동작합니다.

---

## 3. Pod

### 3.1 Pod란?

Pod는 Kubernetes에서 생성하고 관리할 수 있는 **가장 작은 배포 단위**입니다.

- 하나 이상의 컨테이너 그룹
- 스토리지/네트워크 리소스 공유
- 동일 Pod 내 컨테이너는 같은 IP 주소 공유
- 보통 하나의 Pod에 하나의 컨테이너 (사이드카 패턴 제외)

### 3.2 Pod YAML 예제

`examples/pod.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
    tier: frontend
spec:
  containers:
  - name: nginx
    image: nginx:1.27
    ports:
    - containerPort: 80
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

### 3.3 Pod 생성 과정

```
1. kubectl apply -f pod.yaml
           │
           ▼
2. kube-apiserver가 요청 수신 및 검증
           │
           ▼
3. etcd에 Pod 정보 저장 (nodeName 없음)
           │
           ▼
4. kube-scheduler가 감지 (watch)
           │
           ▼
5. 적절한 Node 선택 후 nodeName 업데이트
           │
           ▼
6. 해당 Node의 kubelet이 감지
           │
           ▼
7. kubelet이 Container Runtime으로 컨테이너 생성
           │
           ▼
8. Pod 상태 업데이트 (Running)
```

### 3.4 Pod 실습

```bash
# Pod 생성
kubectl apply -f examples/pod.yaml

# Pod 상태 확인
kubectl get pods
kubectl get pods -o wide

# Pod 상세 정보
kubectl describe pod nginx-pod

# Pod 로그
kubectl logs nginx-pod

# Pod 내부 접속
kubectl exec -it nginx-pod -- /bin/bash

# Pod 삭제
kubectl delete pod nginx-pod
```

---

## 4. ReplicaSet

### 4.1 ReplicaSet이란?

ReplicaSet은 지정된 수의 Pod 복제본(replica)이 항상 실행되도록 보장합니다.

**주요 역할:**
- Pod 복제본 수 유지
- Pod 장애 시 자동 복구
- 셀렉터(selector)로 관리할 Pod 식별

### 4.2 ReplicaSet YAML 예제

`examples/replicaset.yaml`:
```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-replicaset
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
```

**구조 이해:**

```
ReplicaSet
├── metadata: ReplicaSet 자체의 정보
├── spec:
│   ├── replicas: 유지할 Pod 수
│   ├── selector: 관리할 Pod를 식별하는 조건
│   └── template: 새 Pod 생성 시 사용할 템플릿 (Pod spec과 동일)
```

### 4.3 ReplicaSet 실습

```bash
# ReplicaSet 생성
kubectl apply -f examples/replicaset.yaml

# ReplicaSet 확인
kubectl get replicaset
kubectl get rs  # 축약형

# Pod 확인 (3개 생성됨)
kubectl get pods

# Pod 하나 삭제해보기 (자동 복구 확인)
kubectl delete pod <pod-name>
kubectl get pods  # 새 Pod가 생성됨

# ReplicaSet 삭제
kubectl delete rs nginx-replicaset
```

---

## 5. Deployment

### 5.1 Deployment란?

Deployment는 ReplicaSet을 관리하고, Pod의 선언적 업데이트를 제공합니다.

**Deployment가 제공하는 기능:**
- ReplicaSet 관리
- 롤링 업데이트
- 롤백
- 스케일링
- 일시 중지/재개

**계층 구조:**
```
Deployment
    │
    └── ReplicaSet
            │
            ├── Pod
            ├── Pod
            └── Pod
```

### 5.2 Deployment YAML 예제

`examples/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

**롤링 업데이트 전략:**

| 옵션 | 설명 |
|------|------|
| `maxSurge` | 원하는 replica 수 대비 초과 생성 가능한 Pod 수 |
| `maxUnavailable` | 업데이트 중 사용 불가능할 수 있는 최대 Pod 수 |

### 5.3 Deployment 실습

#### 5.3.1 Deployment 생성

```bash
# Deployment 생성
kubectl apply -f examples/deployment.yaml

# Deployment 확인
kubectl get deployments
kubectl get deploy  # 축약형

# ReplicaSet 확인
kubectl get rs

# Pod 확인
kubectl get pods
```

#### 5.3.2 롤링 업데이트

```bash
# 이미지 업데이트 (nginx 1.27 → 1.28)
kubectl set image deployment/nginx-deployment nginx=nginx:1.27

# 업데이트 상태 확인
kubectl rollout status deployment/nginx-deployment

# ReplicaSet 확인 (새 ReplicaSet 생성됨)
kubectl get rs

# Pod 확인 (순차적으로 교체됨)
kubectl get pods -w  # watch 모드
```

#### 5.3.3 롤백

```bash
# 롤아웃 히스토리 확인
kubectl rollout history deployment/nginx-deployment

# 이전 버전으로 롤백
kubectl rollout undo deployment/nginx-deployment

# 특정 리비전으로 롤백
kubectl rollout undo deployment/nginx-deployment --to-revision=1

# 롤백 확인
kubectl rollout status deployment/nginx-deployment
```

#### 5.3.4 스케일링

```bash
# replica 수 변경
kubectl scale deployment/nginx-deployment --replicas=5

# 확인
kubectl get deploy
kubectl get pods

# 다시 3개로 축소
kubectl scale deployment/nginx-deployment --replicas=3
```

#### 5.3.5 YAML 파일 수정으로 업데이트

```bash
# 직접 편집
kubectl edit deployment/nginx-deployment

# 또는 YAML 파일 수정 후 apply
kubectl apply -f examples/deployment.yaml
```

---

## 6. 기타 워크로드 오브젝트

### 6.1 DaemonSet

모든 (또는 일부) Node에 Pod를 하나씩 실행합니다.

**사용 사례:**
- 로그 수집 에이전트 (Fluentd, Filebeat)
- 모니터링 에이전트 (Prometheus Node Exporter)
- 네트워크 플러그인 (Cilium, Calico)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  selector:
    matchLabels:
      name: fluentd
  template:
    metadata:
      labels:
        name: fluentd
    spec:
      containers:
      - name: fluentd
        image: fluentd:v1.14
```

### 6.2 StatefulSet

상태를 가지는 애플리케이션을 위한 워크로드입니다.

**특징:**
- 안정적인 네트워크 식별자 (pod-0, pod-1, ...)
- 안정적인 영구 스토리지
- 순서 보장 (생성/삭제/업데이트)

**사용 사례:**
- 데이터베이스 (MySQL, PostgreSQL)
- 분산 시스템 (Kafka, ZooKeeper, Elasticsearch)

### 6.3 Job / CronJob

**Job**: 하나 이상의 Pod를 생성하고 성공적으로 종료될 때까지 재시도

**CronJob**: 주기적으로 Job 생성

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-job
spec:
  schedule: "0 2 * * *"  # 매일 새벽 2시
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: backup-tool:latest
          restartPolicy: OnFailure
```

---

## 7. 실습 정리

### 7.1 오늘 배운 내용

1. **Control Plane 컴포넌트**: apiserver, etcd, scheduler, controller-manager
2. **Worker Node 컴포넌트**: kubelet, kube-proxy
3. **Kubernetes Object**: 선언적 관리, YAML 구조
4. **Pod**: 최소 배포 단위, 컨테이너 그룹
5. **ReplicaSet**: Pod 복제본 관리
6. **Deployment**: ReplicaSet 관리, 롤링 업데이트, 롤백, 스케일링

### 7.2 주요 명령어 정리

```bash
# 리소스 조회
kubectl get pods/deploy/rs
kubectl describe <resource> <name>

# 리소스 생성/수정
kubectl apply -f <file.yaml>
kubectl edit <resource> <name>

# Deployment 관리
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>
kubectl scale deployment/<name> --replicas=<n>

# 로그/디버깅
kubectl logs <pod-name>
kubectl exec -it <pod-name> -- /bin/bash
```

### 7.3 다음 주차 예고

3주차에서는 VM 3대를 사용하여 실제 Kubeadm 클러스터를 구축합니다.
- VM 환경 준비 및 사전 설정
- Containerd 설치
- Kubeadm으로 클러스터 초기화
- Cilium CNI 설치

---

## 참고 자료

- [Kubernetes 공식 문서 - Pod](https://kubernetes.io/ko/docs/concepts/workloads/pods/)
- [Kubernetes 공식 문서 - Deployment](https://kubernetes.io/ko/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes 공식 문서 - ReplicaSet](https://kubernetes.io/ko/docs/concepts/workloads/controllers/replicaset/)
