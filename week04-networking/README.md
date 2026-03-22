# 4주차: Service와 Pod 네트워킹

## 학습 목표

- Kubernetes 네트워크 모델을 이해합니다.
- Service의 개념과 종류(ClusterIP, NodePort, LoadBalancer)를 학습합니다.
- DNS를 통한 서비스 디스커버리를 이해합니다.
- 멀티 컨테이너 Pod 패턴을 학습합니다.

---

## 1. Kubernetes 네트워크 개요

### 1.1 네트워크 요구사항

Kubernetes는 다음 네트워크 요구사항을 만족해야 합니다:

1. **Pod-to-Pod**: 모든 Pod는 NAT 없이 다른 모든 Pod와 통신 가능
2. **Node-to-Pod**: 모든 Node는 NAT 없이 모든 Pod와 통신 가능
3. **Pod 자기 인식**: Pod가 보는 자신의 IP = 다른 Pod가 보는 해당 Pod의 IP

### 1.2 네트워크 계층

```
┌─────────────────────────────────────────────────────┐
│                   External Traffic                   │
│                   (인터넷, 외부)                      │
└──────────────────────┬──────────────────────────────┘
                       │
          ┌────────────▼────────────┐
          │   Ingress / LoadBalancer │
          │   (L7 / L4 라우팅)        │
          └────────────┬────────────┘
                       │
          ┌────────────▼────────────┐
          │        Service          │
          │   (서비스 추상화 계층)    │
          └────────────┬────────────┘
                       │
          ┌────────────▼────────────┐
          │         Pod             │
          │   (애플리케이션 컨테이너) │
          └─────────────────────────┘
```

### 1.3 Pod IP와 Container Network

```
┌─────────────── Pod (10.244.1.5) ──────────────┐
│                                               │
│  ┌─────────────┐    ┌─────────────┐           │
│  │ Container A │    │ Container B │           │
│  │  (app)      │    │  (sidecar)  │           │
│  │  port:8080  │    │  port:9090  │           │
│  └──────┬──────┘    └──────┬──────┘           │
│         │                  │                  │
│  ───────┴──────────────────┴───────           │
│                Network Namespace              │
│              (localhost 공유)                  │
│                                               │
└───────────────────────────────────────────────┘
```

- Pod 내 컨테이너들은 **동일한 Network Namespace** 공유
- `localhost`로 서로 통신 가능
- 각 Pod는 **고유한 IP 주소** 할당

---

## 2. Service 개념

### 2.1 Service가 필요한 이유

Pod는 언제든 삭제/재생성될 수 있어 IP가 변경됩니다:

```
┌─────────────────────────────────────────────────────┐
│  문제 상황: Pod IP는 변경됨                           │
├─────────────────────────────────────────────────────┤
│                                                     │
│   Frontend Pod ──X──> Backend Pod (IP: 10.244.1.5)  │
│                       (삭제됨)                       │
│                                                     │
│   Frontend Pod ──?──> Backend Pod (IP: 10.244.2.8)  │
│                       (새로 생성, IP 변경)            │
│                                                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  해결: Service 사용                                  │
├─────────────────────────────────────────────────────┤
│                                                     │
│   Frontend Pod ────> Service ────> Backend Pod      │
│              (고정 IP/DNS)   (자동 라우팅)            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### 2.2 Service 동작 원리

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: backend    # label selector로 Pod 선택
  ports:
  - port: 80        # Service 포트
    targetPort: 8080 # Pod 컨테이너 포트
```

Service는 **Label Selector**를 사용하여 Pod를 선택합니다:

```
┌────────────────────────────────────────────────────┐
│                    Service                          │
│              selector: app=backend                  │
│                    │                                │
│       ┌───────────┼───────────┐                    │
│       ▼           ▼           ▼                    │
│   ┌───────┐   ┌───────┐   ┌───────┐                │
│   │ Pod A │   │ Pod B │   │ Pod C │                │
│   │app=   │   │app=   │   │app=   │                │
│   │backend│   │backend│   │backend│                │
│   └───────┘   └───────┘   └───────┘                │
│                                                     │
│   Pod D (app=frontend) ─ 선택되지 않음              │
└────────────────────────────────────────────────────┘
```

### 2.3 Endpoints

Service와 연결된 Pod IP 목록:

```bash
# Endpoints 확인
kubectl get endpoints my-service
```

```
NAME         ENDPOINTS                                  AGE
my-service   10.244.1.5:8080,10.244.2.6:8080,...       5m
```

---

## 3. Service 타입

### 3.1 ClusterIP (기본값)

클러스터 **내부에서만** 접근 가능한 가상 IP:

```yaml
# examples/service-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP  # 기본값, 생략 가능
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 8080
```

```
┌─────────────────── Cluster ───────────────────┐
│                                               │
│   Frontend Pod ────> backend-service          │
│                      (10.96.0.100:80)         │
│                          │                    │
│              ┌───────────┼───────────┐        │
│              ▼           ▼           ▼        │
│          Pod:8080    Pod:8080    Pod:8080     │
│                                               │
│   ✗ 외부에서 접근 불가                          │
└───────────────────────────────────────────────┘
```

**사용 사례:**
- 백엔드 서비스
- 데이터베이스
- 내부 마이크로서비스

### 3.2 NodePort

클러스터 **외부에서** Node IP:NodePort로 접근:

```yaml
# examples/service-nodeport.yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080  # 30000-32767 범위, 생략시 자동 할당
```

```
┌──────────────────────────────────────────────────────────┐
│                     External Client                       │
│                          │                                │
│              http://192.168.1.10:30080                    │
│              http://192.168.1.11:30080                    │
│              http://192.168.1.12:30080                    │
│                          │                                │
└──────────────────────────┼────────────────────────────────┘
                           │
┌──────────────────────────▼────────────────────────────────┐
│                       Cluster                             │
│   ┌────────────┐  ┌────────────┐  ┌────────────┐          │
│   │  Node 1    │  │  Node 2    │  │  Node 3    │          │
│   │  :30080    │  │  :30080    │  │  :30080    │          │
│   └─────┬──────┘  └─────┬──────┘  └─────┬──────┘          │
│         │               │               │                 │
│         └───────────────┼───────────────┘                 │
│                         ▼                                 │
│                  frontend-service                         │
│                         │                                 │
│              ┌──────────┼──────────┐                      │
│              ▼          ▼          ▼                      │
│           Pod:8080   Pod:8080   Pod:8080                  │
└───────────────────────────────────────────────────────────┘
```

**사용 사례:**
- 개발/테스트 환경
- On-premise 환경
- LoadBalancer 사용 불가 시

### 3.3 LoadBalancer

클라우드 제공자의 **로드밸런서** 연동:

```yaml
# examples/service-loadbalancer.yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
```

```
┌────────────────────────────────────────────────────────────┐
│                    External Client                          │
│                          │                                  │
│           http://34.123.45.67 (External IP)                 │
│                          │                                  │
└──────────────────────────┼──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│               Cloud Load Balancer                           │
│            (AWS ELB / GCP LB / Azure LB)                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                        Cluster                              │
│   ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│   │  Node 1    │  │  Node 2    │  │  Node 3    │            │
│   │  :30080    │  │  :30080    │  │  :30080    │            │
│   └────────────┘  └────────────┘  └────────────┘            │
│                         │                                   │
│                  web-service (ClusterIP)                    │
│                         │                                   │
│              ┌──────────┼──────────┐                        │
│              ▼          ▼          ▼                        │
│           Pod:8080   Pod:8080   Pod:8080                    │
└─────────────────────────────────────────────────────────────┘
```

**사용 사례:**
- 클라우드 프로덕션 환경
- 외부 서비스 노출
- 관리형 로드밸런싱

### 3.4 ExternalName

클러스터 외부 서비스를 DNS로 참조:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-db
spec:
  type: ExternalName
  externalName: db.example.com
```

Pod에서 `external-db`로 접근하면 `db.example.com`으로 연결됩니다.

---

## 4. DNS와 서비스 디스커버리

### 4.1 Kubernetes DNS

모든 Service는 자동으로 DNS 레코드를 갖습니다:

```
<service-name>.<namespace>.svc.cluster.local
```

예시:
- `backend-service.default.svc.cluster.local`
- 같은 namespace에서는 `backend-service`만으로 접근 가능

### 4.2 DNS 조회 테스트

```bash
# DNS 테스트용 Pod 실행
kubectl run dns-test --image=busybox --restart=Never --rm -it -- sh

# Pod 내부에서 DNS 조회
nslookup backend-service
nslookup backend-service.default.svc.cluster.local

# 다른 namespace의 서비스 조회
nslookup kubernetes.default.svc.cluster.local
```

### 4.3 환경 변수를 통한 서비스 디스커버리

Pod가 생성될 때, 같은 namespace의 Service 정보가 환경 변수로 주입됩니다:

```bash
# Pod 내부에서 환경 변수 확인
env | grep SERVICE

# 출력 예시:
# BACKEND_SERVICE_SERVICE_HOST=10.96.0.100
# BACKEND_SERVICE_SERVICE_PORT=80
```

---

## 5. 멀티 컨테이너 Pod 패턴

### 5.1 개요

하나의 Pod에 여러 컨테이너를 실행하는 패턴입니다.

**동일 Pod 내 컨테이너 특성:**
- 동일한 Network Namespace (localhost 통신)
- 동일한 Storage Volume 공유 가능
- 동일한 Node에서 실행
- 함께 생성/삭제

### 5.2 Sidecar 패턴

메인 컨테이너를 보조하는 컨테이너:

```yaml
# examples/pod-sidecar.yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-pod
spec:
  containers:
  # 메인 컨테이너: nginx 웹 서버
  - name: web
    image: nginx:1.27
    ports:
    - containerPort: 80
    volumeMounts:
    - name: html
      mountPath: /usr/share/nginx/html

  # 사이드카: 5초마다 웹 페이지 업데이트
  - name: content-updater
    image: busybox:1.36
    command: ['sh', '-c', 'while true; do date > /html/index.html; sleep 5; done']
    volumeMounts:
    - name: html
      mountPath: /html

  # 두 컨테이너가 공유하는 디렉토리 (5주차에서 자세히 학습)
  volumes:
  - name: html
    emptyDir: {}
```

```
┌──────────────────── Pod ────────────────────┐
│                                             │
│  ┌─────────────────┐  ┌──────────────────┐  │
│  │  web (nginx)    │  │ content-updater  │  │
│  │  :80            │  │ (busybox)        │  │
│  │                 │  │                  │  │
│  │  웹 페이지 서빙  │  │ 5초마다 index.html│  │
│  │                 │  │ 업데이트          │  │
│  └────────┬────────┘  └────────┬─────────┘  │
│           │                    │            │
│           └─────────┬──────────┘            │
│                     │                       │
│              Shared Volume                  │
│              (/html)                        │
│                                             │
└─────────────────────────────────────────────┘
```

핵심은 **nginx(메인)의 코드를 전혀 수정하지 않고**, 사이드카가 콘텐츠를 주입한다는 점입니다.

**Sidecar 사용 사례:**
- 로그 수집 (Fluent Bit, Filebeat)
- 모니터링 (Prometheus exporter)
- 프록시 (Envoy, Istio sidecar)
- 설정 동기화

### 5.3 Ambassador 패턴

외부 통신을 대행하는 프록시 컨테이너:

```yaml
# examples/pod-ambassador.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-ambassador
spec:
  containers:
  # 메인 애플리케이션 - localhost로 DB 접근
  - name: app
    image: myapp
    env:
    - name: DB_HOST
      value: "localhost"
    - name: DB_PORT
      value: "5432"

  # Ambassador: 외부 DB로 연결 중계
  - name: db-proxy
    image: haproxy
    ports:
    - containerPort: 5432
```

```
┌─────────────── Pod ───────────────┐
│                                   │
│  ┌─────────────┐  ┌─────────────┐ │         ┌──────────┐
│  │    app      │  │  db-proxy   │ │         │ External │
│  │   (main)    │→│ (ambassador)│─┼────────→│    DB    │
│  │localhost:   │  │             │ │         │          │
│  │   5432      │  │    :5432    │ │         └──────────┘
│  └─────────────┘  └─────────────┘ │
│                                   │
└───────────────────────────────────┘
```

### 5.4 Adapter 패턴

데이터 형식을 변환하는 컨테이너:

```yaml
# examples/pod-adapter.yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-adapter
spec:
  containers:
  # 메인 애플리케이션 - 비표준 형식 로그 생성
  - name: app
    image: legacy-app
    volumeMounts:
    - name: logs
      mountPath: /app/logs

  # Adapter: 로그 형식 변환 (Prometheus 형식으로)
  - name: log-adapter
    image: log-transformer
    ports:
    - containerPort: 9090  # Prometheus metrics endpoint
    volumeMounts:
    - name: logs
      mountPath: /input

  volumes:
  - name: logs
    emptyDir: {}
```

```
┌─────────────── Pod ───────────────┐
│                                   │
│  ┌─────────────┐  ┌─────────────┐ │      ┌──────────────┐
│  │ legacy-app  │  │   adapter   │ │      │  Prometheus  │
│  │   (main)    │→│  (metrics   │─┼─────→│              │
│  │             │  │  converter) │ │      │              │
│  └─────────────┘  └─────────────┘ │      └──────────────┘
│         │                │        │
│         └───────┬────────┘        │
│          Shared Volume            │
└───────────────────────────────────┘
```

---

## 6. 실습

### 6.1 Deployment와 Service 생성

```bash
# Deployment 생성
kubectl apply -f examples/deployment-nginx.yaml

# ClusterIP Service 생성
kubectl apply -f examples/service-clusterip.yaml

# 확인
kubectl get svc
kubectl get endpoints
```

### 6.2 Service 접근 테스트

```bash
# 임시 Pod에서 Service 접근 테스트
kubectl run test-pod --image=busybox --restart=Never --rm -it -- sh

# Pod 내부에서
wget -qO- backend-service
wget -qO- backend-service.default.svc.cluster.local
```

### 6.3 NodePort Service 테스트

```bash
# NodePort Service 생성
kubectl apply -f examples/service-nodeport.yaml

# 확인
kubectl get svc frontend-service

# 외부에서 접근 (노드 IP:NodePort)
curl http://<NODE-IP>:30080
```

> **Bastion 서버를 통해 접근하는 환경인 경우**
>
> NodePort는 클러스터 노드의 IP로 직접 접근해야 하지만, Bastion(점프 호스트)을 경유하는 환경에서는 로컬 PC에서 노드 IP로 바로 접근할 수 없습니다.
> 이 경우 **SSH 포트 포워딩**을 사용하여 로컬 포트를 노드의 NodePort로 터널링합니다.
>
> ```bash
> # 로컬 8080 포트 → Kubernetes 노드의 30080 포트로 SSH 터널링
> ssh -o ExitOnForwardFailure=yes -L 8080:localhost:30080 <Kubernetes Node IP> "echo 'Tunneling... Press Ctrl+C to stop'; sleep infinity"
> ```
>
> 터널링이 연결되면 브라우저에서 **`http://localhost:8080`** 으로 접근하여 서비스를 확인할 수 있습니다.

### 6.4 Sidecar 패턴 실습

nginx 웹 서버(메인) + busybox 콘텐츠 업데이터(사이드카) 조합입니다.
사이드카가 5초마다 `index.html`을 갱신하고, nginx는 이를 서빙합니다.

```bash
# Sidecar Pod 생성
kubectl apply -f examples/pod-sidecar.yaml

# 2개 컨테이너가 모두 Running인지 확인 (2/2)
kubectl get pod sidecar-pod

# 컨테이너 이름 확인
kubectl get pod sidecar-pod -o jsonpath='{.spec.containers[*].name}'
# 출력: web content-updater
```

**사이드카가 동작하는지 확인해 봅시다:**

```bash
# nginx가 서빙하는 페이지 확인 — 현재 시간이 표시됨
kubectl exec sidecar-pod -c web -- curl -s localhost

# 몇 초 후 다시 실행 — 시간이 바뀐 것을 확인!
kubectl exec sidecar-pod -c web -- curl -s localhost
```

> **포인트:** nginx의 설정이나 이미지를 전혀 수정하지 않았는데도,
> 사이드카 컨테이너가 공유 디렉토리를 통해 웹 페이지를 계속 업데이트하고 있습니다.
> 이것이 사이드카 패턴의 핵심입니다 — **메인 앱을 건드리지 않고 기능을 보조합니다.**

```bash
# 포트포워딩으로 브라우저에서도 확인 가능
kubectl port-forward sidecar-pod 8080:80
# 브라우저에서 http://localhost:8080 접속 후 새로고침하면 시간이 변함

# 사이드카 컨테이너 로그 확인
kubectl logs sidecar-pod -c content-updater

# 정리
kubectl delete pod sidecar-pod
```

---

## 7. 실습 정리

### 7.1 리소스 정리

```bash
kubectl delete -f examples/
```

### 7.2 오늘 배운 내용

1. **Kubernetes 네트워크**: Pod-to-Pod, Node-to-Pod 통신 모델
2. **Service**: Pod에 대한 안정적인 네트워크 엔드포인트
3. **Service 타입**: ClusterIP, NodePort, LoadBalancer
4. **DNS**: 서비스 디스커버리와 DNS 기반 접근
5. **멀티 컨테이너 패턴**: Sidecar, Ambassador, Adapter

### 7.3 다음 주차 예고

5주차에서는 Kubernetes Storage를 학습합니다:
- Volume 종류 (emptyDir, hostPath 등)
- PersistentVolume (PV)
- PersistentVolumeClaim (PVC)
- StorageClass

---

## 참고 자료

- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [Multi-container Pods](https://kubernetes.io/docs/concepts/workloads/pods/#using-pods)
- [Cilium Network Policy](https://docs.cilium.io/en/stable/security/policy/)
