# 6주차: Kubernetes 운영 기초

## 학습 목표

- ConfigMap과 Secret을 활용한 설정 관리를 학습합니다.
- Resource 관리(requests/limits)를 이해합니다.
- 헬스체크(Liveness/Readiness/Startup Probe)를 구성합니다.
- 롤링 업데이트와 롤백 전략을 이해합니다.

---

## 1. ConfigMap

### 1.1 ConfigMap이란?

애플리케이션 설정을 코드와 분리하여 관리하는 Kubernetes 객체입니다.

```
┌─────────────────────────────────────────────────────┐
│              기존 방식 (Bad)                         │
│                                                     │
│  ┌──────────────────────────────┐                   │
│  │      Container Image         │                   │
│  │  ┌─────────────────────┐     │                   │
│  │  │ Application Code    │     │                   │
│  │  │ +                   │     │                   │
│  │  │ Configuration ←─────┼─────┼── 이미지 재빌드 필요│
│  │  └─────────────────────┘     │                   │
│  └──────────────────────────────┘                   │
│                                                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│              ConfigMap 방식 (Good)                  │
│                                                     │
│  ┌──────────────────────────────┐   ┌────────────┐ │
│  │      Container Image         │   │ ConfigMap  │ │
│  │  ┌─────────────────────┐     │   │            │ │
│  │  │ Application Code    │◄────┼───┤ 설정값     │ │
│  │  │                     │     │   │            │ │
│  │  └─────────────────────┘     │   └────────────┘ │
│  └──────────────────────────────┘                   │
│  → 설정 변경 시 이미지 재빌드 불필요                   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 1.2 ConfigMap 생성

**YAML로 생성:**
```yaml
# examples/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  # 단순 키-값
  DATABASE_HOST: "mysql.default.svc.cluster.local"
  DATABASE_PORT: "3306"
  LOG_LEVEL: "info"

  # 파일 형태
  app.properties: |
    server.port=8080
    spring.profiles.active=production
    logging.level.root=INFO
```

**명령어로 생성:**
```bash
# 리터럴 값으로 생성
kubectl create configmap app-config \
  --from-literal=DATABASE_HOST=mysql \
  --from-literal=DATABASE_PORT=3306

# 파일에서 생성
kubectl create configmap app-config --from-file=config.properties

# 디렉토리에서 생성
kubectl create configmap app-config --from-file=configs/
```

### 1.3 ConfigMap 사용

**환경 변수로 주입:**
```yaml
# examples/pod-configmap-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp
    env:
    # 개별 키 참조
    - name: DB_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: DATABASE_HOST

    # 전체 ConfigMap을 환경변수로
    envFrom:
    - configMapRef:
        name: app-config
```

**볼륨으로 마운트:**
```yaml
# examples/pod-configmap-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true

  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

---

## 2. Secret

### 2.1 Secret이란?

비밀번호, 토큰, 키 등 민감한 정보를 저장하는 객체입니다.

```
┌────────────────────────────────────────────────────┐
│                 Secret 특징                         │
├────────────────────────────────────────────────────┤
│                                                    │
│  • Base64 인코딩 (암호화 아님!)                     │
│  • etcd에 저장 (암호화 설정 가능)                   │
│  • RBAC으로 접근 제어                              │
│  • 환경 변수 또는 볼륨으로 Pod에 전달              │
│                                                    │
└────────────────────────────────────────────────────┘
```

### 2.2 Secret 타입

| Type | 설명 |
|------|------|
| `Opaque` | 임의의 사용자 정의 데이터 (기본값) |
| `kubernetes.io/service-account-token` | ServiceAccount 토큰 |
| `kubernetes.io/dockerconfigjson` | Docker 레지스트리 인증 |
| `kubernetes.io/tls` | TLS 인증서 |
| `kubernetes.io/basic-auth` | HTTP Basic Auth |

### 2.3 Secret 생성

**YAML로 생성:**
```yaml
# examples/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  # Base64 인코딩된 값
  # echo -n 'admin' | base64  →  YWRtaW4=
  username: YWRtaW4=
  password: cGFzc3dvcmQxMjM=
```

**stringData 사용 (평문):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
stringData:
  # 평문으로 작성, 자동으로 Base64 인코딩됨
  username: admin
  password: password123
```

**명령어로 생성:**
```bash
# 리터럴 값으로 생성
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=password123

# 파일에서 생성
kubectl create secret generic tls-cert \
  --from-file=tls.crt=server.crt \
  --from-file=tls.key=server.key

# Docker 레지스트리 인증
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=user \
  --docker-password=pass
```

### 2.4 Secret 사용

**환경 변수로 주입:**
```yaml
# examples/pod-secret-env.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp
    env:
    - name: DB_USERNAME
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
```

**볼륨으로 마운트:**
```yaml
# examples/pod-secret-volume.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true

  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
      defaultMode: 0400  # 파일 권한
```

---

## 3. Resource Management

### 3.1 Requests와 Limits

```yaml
resources:
  requests:    # 최소 보장 리소스 (스케줄링 기준)
    memory: "64Mi"
    cpu: "250m"
  limits:      # 최대 사용 가능 리소스
    memory: "128Mi"
    cpu: "500m"
```

```
┌─────────────────────────────────────────────────────┐
│                 Resource 동작                        │
├─────────────────────────────────────────────────────┤
│                                                     │
│  CPU:                                               │
│  ├─ requests: 스케줄링 기준 (이만큼 필요)            │
│  └─ limits: 초과 시 throttling (느려짐)             │
│                                                     │
│  Memory:                                            │
│  ├─ requests: 스케줄링 기준                         │
│  └─ limits: 초과 시 OOMKill (강제 종료)             │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 3.2 CPU 단위

| 표현 | 의미 |
|------|------|
| `1` | 1 vCPU / 1 Core |
| `500m` | 0.5 vCPU (밀리코어) |
| `250m` | 0.25 vCPU |
| `100m` | 0.1 vCPU |

### 3.3 Memory 단위

| 표현 | 의미 |
|------|------|
| `128Mi` | 128 Mebibytes (1024 기반) |
| `1Gi` | 1 Gibibyte |
| `128M` | 128 Megabytes (1000 기반) |
| `1G` | 1 Gigabyte |

### 3.4 QoS (Quality of Service) Class

리소스 설정에 따른 Pod 우선순위:

| QoS Class | 조건 | 우선순위 |
|-----------|------|----------|
| `Guaranteed` | 모든 컨테이너에 requests=limits 설정 | 가장 높음 |
| `Burstable` | 일부만 설정 또는 requests ≠ limits | 중간 |
| `BestEffort` | requests/limits 미설정 | 가장 낮음 (먼저 죽음) |

```yaml
# examples/pod-resources.yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
  - name: app
    image: nginx:1.27
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

---

## 4. 헬스체크 (Probes)

### 4.1 Probe 종류

```
┌─────────────────────────────────────────────────────────┐
│                    Probe Types                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Liveness Probe:                                        │
│  └─ "컨테이너가 살아있는가?"                              │
│     → 실패 시 컨테이너 재시작                             │
│                                                         │
│  Readiness Probe:                                       │
│  └─ "트래픽을 받을 준비가 되었는가?"                      │
│     → 실패 시 Service 엔드포인트에서 제외                 │
│                                                         │
│  Startup Probe:                                         │
│  └─ "애플리케이션이 시작되었는가?"                        │
│     → 성공 전까지 다른 probe 비활성화                     │
│     → 느린 시작 애플리케이션용                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Probe 메커니즘

| 메커니즘 | 설명 |
|----------|------|
| `httpGet` | HTTP GET 요청, 2xx-3xx 응답이면 성공 |
| `tcpSocket` | TCP 연결 시도, 연결되면 성공 |
| `exec` | 컨테이너 내 명령 실행, 종료코드 0이면 성공 |
| `grpc` | gRPC 헬스체크 (Kubernetes 1.24+) |

### 4.3 Probe 설정 예시

```yaml
# examples/pod-probes.yaml
apiVersion: v1
kind: Pod
metadata:
  name: probe-demo
spec:
  containers:
  - name: app
    image: nginx:1.27
    ports:
    - containerPort: 80

    # Startup Probe: 앱이 시작될 때까지 대기
    startupProbe:
      httpGet:
        path: /healthz
        port: 80
      failureThreshold: 30  # 최대 30번 시도 (30*10=300초)
      periodSeconds: 10

    # Liveness Probe: 컨테이너 생존 확인
    livenessProbe:
      httpGet:
        path: /healthz
        port: 80
      initialDelaySeconds: 0   # startupProbe 성공 후 시작
      periodSeconds: 10        # 10초마다 체크
      timeoutSeconds: 1        # 응답 타임아웃
      failureThreshold: 3      # 3번 실패 시 재시작

    # Readiness Probe: 트래픽 수신 준비 확인
    readinessProbe:
      httpGet:
        path: /ready
        port: 80
      initialDelaySeconds: 0
      periodSeconds: 5
      timeoutSeconds: 1
      successThreshold: 1      # 1번 성공 시 Ready
      failureThreshold: 3      # 3번 실패 시 Not Ready
```

### 4.4 TCP/Exec Probe 예시

```yaml
# TCP Socket Probe
livenessProbe:
  tcpSocket:
    port: 3306
  initialDelaySeconds: 15
  periodSeconds: 10

# Exec Probe
livenessProbe:
  exec:
    command:
    - cat
    - /tmp/healthy
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## 5. 롤링 업데이트와 롤백

### 5.1 업데이트 전략

**RollingUpdate (기본값):**
```
┌─────────────────────────────────────────────────────────┐
│              Rolling Update 과정                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  시작:  [v1] [v1] [v1]                                  │
│           │                                             │
│  1단계: [v1] [v1] [v1] [v2]  ← 새 Pod 생성              │
│           │                                             │
│  2단계: [v1] [v1] [v2]       ← 기존 Pod 종료            │
│           │                                             │
│  3단계: [v1] [v1] [v2] [v2]  ← 새 Pod 생성              │
│           │                                             │
│  4단계: [v1] [v2] [v2]       ← 기존 Pod 종료            │
│           │                                             │
│  완료:  [v2] [v2] [v2]                                  │
│                                                         │
│  → 무중단 배포 (Zero Downtime)                          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Recreate:**
```
┌─────────────────────────────────────────────────────────┐
│                Recreate 과정                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  시작:  [v1] [v1] [v1]                                  │
│           │                                             │
│  1단계: [ ] [ ] [ ]         ← 모든 Pod 종료 (다운타임!) │
│           │                                             │
│  2단계: [v2] [v2] [v2]      ← 새 Pod 생성               │
│                                                         │
│  → 다운타임 발생                                         │
│  → 동시에 두 버전 실행 불가한 경우 사용                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 5.2 RollingUpdate 설정

```yaml
# examples/deployment-rolling.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rolling-demo
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1        # 동시에 생성할 추가 Pod 수 (또는 %)
      maxUnavailable: 0  # 업데이트 중 사용 불가 Pod 수 (또는 %)
  selector:
    matchLabels:
      app: demo
  template:
    metadata:
      labels:
        app: demo
    spec:
      containers:
      - name: app
        image: nginx:1.26  # 업데이트할 이미지
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
```

### 5.3 업데이트 실행

```bash
# 이미지 업데이트
kubectl set image deployment/rolling-demo app=nginx:1.27

# 또는 YAML 수정 후 적용
kubectl apply -f deployment-rolling.yaml

# 업데이트 진행 상황 확인
kubectl rollout status deployment/rolling-demo

# 업데이트 기록 확인
kubectl rollout history deployment/rolling-demo
```

### 5.4 롤백

```bash
# 직전 버전으로 롤백
kubectl rollout undo deployment/rolling-demo

# 특정 리비전으로 롤백
kubectl rollout history deployment/rolling-demo  # 리비전 확인
kubectl rollout undo deployment/rolling-demo --to-revision=2

# 일시 중지/재개
kubectl rollout pause deployment/rolling-demo
kubectl rollout resume deployment/rolling-demo
```

---

## 6. 실습

### 6.1 ConfigMap/Secret 실습

```bash
# ConfigMap 생성
kubectl apply -f examples/configmap.yaml

# Secret 생성
kubectl apply -f examples/secret.yaml

# Pod 생성
kubectl apply -f examples/pod-configmap-env.yaml

# 환경변수 확인
kubectl exec pod-configmap-env -- env | grep -E "DATABASE|LOG"

# Secret 값 확인 (Base64 디코딩)
kubectl get secret db-credentials -o jsonpath='{.data.username}' | base64 -d
```

### 6.2 Resource Limit 실습

```bash
# Resource 제한 Pod 생성
kubectl apply -f examples/pod-resources.yaml

# QoS 클래스 확인
kubectl get pod resource-demo -o jsonpath='{.status.qosClass}'

# 리소스 사용량 확인
kubectl top pod resource-demo
```

### 6.3 Probe 실습

```bash
# Probe 설정된 Deployment 생성
kubectl apply -f examples/deployment-probes.yaml

# Pod 상태 확인
kubectl get pods -w

# Probe 이벤트 확인
kubectl describe pod <pod-name>
```

### 6.4 롤링 업데이트 실습

```bash
# 초기 배포
kubectl apply -f examples/deployment-rolling.yaml

# 이미지 업데이트
kubectl set image deployment/rolling-demo app=nginx:1.27 --record

# 업데이트 진행 상황 확인
kubectl rollout status deployment/rolling-demo

# 히스토리 확인
kubectl rollout history deployment/rolling-demo

# 롤백
kubectl rollout undo deployment/rolling-demo
```

---

## 7. 실습 정리

### 7.1 리소스 정리

```bash
kubectl delete -f examples/
```

### 7.2 오늘 배운 내용

1. **ConfigMap**: 설정 데이터를 코드와 분리
2. **Secret**: 민감한 정보의 안전한 저장
3. **Resource Management**: requests/limits로 리소스 제어
4. **Probes**: Liveness, Readiness, Startup 헬스체크
5. **Rolling Update**: 무중단 배포와 롤백

### 7.3 6주 커리큘럼 완료

축하합니다! 6주간의 Kubernetes 기초 학습을 완료했습니다.

**학습 내용 요약:**

| 주차 | 주제 | 핵심 내용 |
|------|------|----------|
| 1주차 | Minikube 시작 | 컨테이너 개념, Minikube 설치 |
| 2주차 | Workloads | Pod, ReplicaSet, Deployment |
| 3주차 | Kubeadm | VM 기반 클러스터 구축 |
| 4주차 | Networking | Service, DNS, 멀티컨테이너 패턴 |
| 5주차 | Storage | Volume, PV, PVC, StorageClass |
| 6주차 | Operations | ConfigMap, Secret, Probes, 롤링 업데이트 |

### 7.4 다음 단계

- **CKAD 자격증**: Certified Kubernetes Application Developer
- **CKA 자격증**: Certified Kubernetes Administrator
- **심화 주제**: Helm, Ingress, Network Policy, RBAC, Operators

---

## 참고 자료

- [ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Deployments - Rolling Update](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment)
