# 5주차: Kubernetes Storage

## 학습 목표

- Kubernetes Volume의 개념과 종류를 이해합니다.
- PersistentVolume(PV)과 PersistentVolumeClaim(PVC)을 학습합니다.
- StorageClass를 통한 동적 프로비저닝을 이해합니다.
- 실제 환경에서 상태 저장 애플리케이션을 배포합니다.

---

## 1. 컨테이너 스토리지의 문제

### 1.1 컨테이너의 휘발성

컨테이너는 기본적으로 **휘발성(Ephemeral)** 스토리지를 사용합니다:

```
┌───────────────── Container Lifecycle ─────────────────┐
│                                                       │
│   Container Start → Write Data → Container Crash      │
│                         │                             │
│                    [Data Lost!]                       │
│                                                       │
│   New Container Start → No Data                       │
│                                                       │
└───────────────────────────────────────────────────────┘
```

**문제점:**
- 컨테이너 재시작 시 모든 데이터 손실
- Pod 간 데이터 공유 불가
- 상태 저장 애플리케이션(DB 등) 운영 어려움

### 1.2 Volume의 필요성

```
┌───────────────── With Volume ─────────────────────────┐
│                                                       │
│   Container Start → Write to Volume → Container Crash │
│                         │                             │
│                    [Volume persists]                  │
│                                                       │
│   New Container Start → Read from Volume → Data OK!   │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

## 2. Volume 종류

### 2.1 emptyDir

Pod의 생명주기와 함께하는 임시 볼륨:

```yaml
# examples/pod-emptydir.yaml
apiVersion: v1
kind: Pod
metadata:
  name: emptydir-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'echo "Hello" > /data/hello.txt && sleep 3600']
    volumeMounts:
    - name: shared-data
      mountPath: /data

  - name: reader
    image: busybox
    command: ['sh', '-c', 'cat /data/hello.txt && sleep 3600']
    volumeMounts:
    - name: shared-data
      mountPath: /data

  volumes:
  - name: shared-data
    emptyDir: {}
```

```
┌─────────────── Pod ───────────────┐
│                                   │
│  ┌─────────────┐  ┌─────────────┐ │
│  │   writer    │  │   reader    │ │
│  │  /data      │  │  /data      │ │
│  └──────┬──────┘  └──────┬──────┘ │
│         │                │        │
│         └───────┬────────┘        │
│                 │                 │
│          ┌──────▼──────┐          │
│          │  emptyDir   │          │
│          │  (Volume)   │          │
│          └─────────────┘          │
│                                   │
└───────────────────────────────────┘
```

**특징:**
- Pod 시작 시 빈 디렉토리 생성
- Pod 삭제 시 함께 삭제
- 같은 Pod 내 컨테이너 간 데이터 공유
- 임시 캐시, 중간 처리 결과 저장에 적합

**메모리 기반 emptyDir:**
```yaml
volumes:
- name: cache
  emptyDir:
    medium: Memory  # RAM에 저장 (더 빠름)
    sizeLimit: 100Mi
```

### 2.2 hostPath

노드의 파일 시스템을 마운트:

```yaml
# examples/pod-hostpath.yaml
apiVersion: v1
kind: Pod
metadata:
  name: hostpath-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: host-data
      mountPath: /data
      readOnly: true

  volumes:
  - name: host-data
    hostPath:
      path: /var/log  # 노드의 실제 경로
      type: Directory
```

```
┌────────── Node ──────────┐
│                          │
│  ┌────── Pod ──────┐     │
│  │                 │     │
│  │  Container      │     │
│  │   /data ◄───────┼─────┼─── /var/log (Node)
│  │                 │     │
│  └─────────────────┘     │
│                          │
└──────────────────────────┘
```

**hostPath type:**
| Type | 설명 |
|------|------|
| `Directory` | 디렉토리가 존재해야 함 |
| `DirectoryOrCreate` | 없으면 생성 |
| `File` | 파일이 존재해야 함 |
| `FileOrCreate` | 없으면 생성 |
| `Socket` | Unix 소켓이 존재해야 함 |

**주의사항:**
- 특정 노드에 종속
- 보안 위험 (호스트 파일 시스템 접근)
- 주로 DaemonSet에서 노드 로그/메트릭 수집에 사용

### 2.3 ConfigMap과 Secret 볼륨

설정 데이터를 볼륨으로 마운트:

```yaml
# ConfigMap 정의
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  app.properties: |
    database.host=localhost
    database.port=5432

---
# Pod에서 ConfigMap 사용
apiVersion: v1
kind: Pod
metadata:
  name: config-pod
spec:
  containers:
  - name: app
    image: myapp
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config

  volumes:
  - name: config-volume
    configMap:
      name: app-config
```

---

## 3. PersistentVolume (PV)

### 3.1 PV란?

클러스터 레벨의 스토리지 리소스:

```
┌──────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                  │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │            PersistentVolume (PV)                │ │
│  │                                                 │ │
│  │  - 클러스터 관리자가 프로비저닝                   │ │
│  │  - 실제 스토리지와 연결                          │ │
│  │  - 클러스터 레벨 리소스 (namespace 무관)         │ │
│  │                                                 │ │
│  └─────────────────────────────────────────────────┘ │
│                         │                            │
│              ┌──────────▼───────────┐                │
│              │   실제 스토리지       │                │
│              │  (NFS, AWS EBS,      │                │
│              │   Local Disk 등)     │                │
│              └──────────────────────┘                │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 3.2 PV 정의

```yaml
# examples/pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
```

### 3.3 Access Modes

| Mode | 약어 | 설명 |
|------|------|------|
| `ReadWriteOnce` | RWO | 단일 노드에서 읽기/쓰기 |
| `ReadOnlyMany` | ROX | 여러 노드에서 읽기 전용 |
| `ReadWriteMany` | RWX | 여러 노드에서 읽기/쓰기 |
| `ReadWriteOncePod` | RWOP | 단일 Pod에서 읽기/쓰기 |

### 3.4 Reclaim Policy

PVC 삭제 시 PV의 동작:

| Policy | 설명 |
|--------|------|
| `Retain` | PV와 데이터 유지 (수동 정리) |
| `Delete` | PV와 데이터 함께 삭제 |
| `Recycle` | 데이터 삭제 후 재사용 (deprecated) |

---

## 4. PersistentVolumeClaim (PVC)

### 4.1 PVC란?

사용자(개발자)가 스토리지를 요청하는 방법:

```
┌────────────────────── 워크플로우 ──────────────────────┐
│                                                       │
│  Developer                   Cluster Admin            │
│     │                             │                   │
│     │ 1. PVC 생성                 │                   │
│     │ (10Gi 필요)                 │ PV 생성           │
│     │     │                       │ (10Gi 제공)       │
│     ▼     │                       ▼                   │
│  ┌──────────┐                ┌──────────┐             │
│  │   PVC    │───Binding────→│   PV     │             │
│  │  10Gi   │                │  10Gi    │             │
│  └────┬─────┘                └──────────┘             │
│       │                                               │
│       │ 2. Pod에서 PVC 사용                            │
│       ▼                                               │
│  ┌──────────┐                                         │
│  │   Pod    │                                         │
│  └──────────┘                                         │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### 4.2 PVC 정의

```yaml
# examples/pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
```

### 4.3 PVC를 Pod에서 사용

```yaml
# examples/pod-with-pvc.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pvc-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: my-storage
      mountPath: /usr/share/nginx/html

  volumes:
  - name: my-storage
    persistentVolumeClaim:
      claimName: my-pvc
```

### 4.4 PV-PVC 바인딩 조건

PVC가 PV에 바인딩되려면:

1. **Capacity**: PV >= PVC 요청 용량
2. **Access Mode**: PV가 PVC의 access mode 지원
3. **StorageClass**: 동일한 StorageClass (또는 빈 문자열)
4. **Selector**: PVC selector와 PV label 일치 (있는 경우)

```
PVC 요청:                  PV 제공:
- 5Gi                     - 10Gi ✓ (충족)
- ReadWriteOnce           - ReadWriteOnce ✓
- storageClassName: fast  - storageClassName: fast ✓

→ 바인딩 성공!
```

---

## 5. StorageClass와 동적 프로비저닝

### 5.1 정적 vs 동적 프로비저닝

```
┌────────────── 정적 프로비저닝 ──────────────┐
│                                            │
│  1. Admin: PV 생성 (수동)                   │
│  2. User: PVC 생성                          │
│  3. Kubernetes: PV-PVC 바인딩               │
│                                            │
│  단점: 매번 관리자가 PV를 미리 만들어야 함    │
│                                            │
└────────────────────────────────────────────┘

┌────────────── 동적 프로비저닝 ──────────────┐
│                                            │
│  1. Admin: StorageClass 정의 (한 번)        │
│  2. User: PVC 생성                          │
│  3. Kubernetes: PV 자동 생성 및 바인딩       │
│                                            │
│  장점: 필요할 때 자동으로 스토리지 생성       │
│                                            │
└────────────────────────────────────────────┘
```

### 5.2 StorageClass 정의

```yaml
# examples/storageclass.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: kubernetes.io/no-provisioner  # Local용 (동적 프로비저닝 불가)
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

**클라우드 StorageClass 예시:**

```yaml
# AWS EBS
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
volumeBindingMode: WaitForFirstConsumer
```

```yaml
# GCP Persistent Disk
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
volumeBindingMode: WaitForFirstConsumer
```

### 5.3 동적 프로비저닝 사용

```yaml
# PVC만 생성하면 PV 자동 생성
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: fast-storage  # StorageClass 지정
```

### 5.4 기본 StorageClass

```bash
# 기본 StorageClass 확인
kubectl get sc

# 기본 StorageClass 설정
kubectl patch sc fast-storage -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## 6. 실습

### 6.1 emptyDir 실습

```bash
# Pod 생성
kubectl apply -f examples/pod-emptydir.yaml

# writer 컨테이너가 쓴 데이터를 reader가 읽는지 확인
kubectl logs emptydir-pod -c reader
```

### 6.2 PV/PVC 실습

```bash
# 노드에서 디렉토리 생성 (hostPath용)
# Worker 노드에 SSH 접속 후:
# sudo mkdir -p /mnt/data

# PV 생성
kubectl apply -f examples/pv.yaml

# PV 상태 확인
kubectl get pv

# PVC 생성
kubectl apply -f examples/pvc.yaml

# 바인딩 확인
kubectl get pv,pvc

# Pod 생성
kubectl apply -f examples/pod-with-pvc.yaml

# Pod에서 데이터 쓰기
kubectl exec -it pvc-pod -- bash -c "echo 'Hello PV!' > /usr/share/nginx/html/index.html"

# 확인
kubectl exec pvc-pod -- cat /usr/share/nginx/html/index.html
```

### 6.3 MySQL with PVC 실습

```bash
# MySQL 배포
kubectl apply -f examples/mysql-deployment.yaml

# 데이터베이스 확인
kubectl exec -it deploy/mysql -- mysql -uroot -ppassword -e "SHOW DATABASES;"

# 데이터베이스 생성
kubectl exec -it deploy/mysql -- mysql -uroot -ppassword -e "CREATE DATABASE testdb;"

# Pod 삭제 후 재생성
kubectl delete pod -l app=mysql

# 데이터 유지 확인
kubectl exec -it deploy/mysql -- mysql -uroot -ppassword -e "SHOW DATABASES;"
```

---

## 7. 실습 정리

### 7.1 리소스 정리

```bash
kubectl delete -f examples/
```

### 7.2 PV 상태 확인

```
Status    설명
------    ----
Available PVC와 바인딩되지 않음
Bound     PVC와 바인딩됨
Released  PVC 삭제됨, 재사용 대기 (Retain 정책)
Failed    동적 프로비저닝 실패
```

### 7.3 오늘 배운 내용

1. **Volume**: 컨테이너의 휘발성 스토리지 문제 해결
2. **emptyDir/hostPath**: 기본 볼륨 타입
3. **PersistentVolume**: 클러스터 레벨 스토리지 리소스
4. **PersistentVolumeClaim**: 사용자의 스토리지 요청
5. **StorageClass**: 동적 프로비저닝

### 7.4 다음 주차 예고

6주차에서는 Kubernetes 운영을 학습합니다:
- ConfigMap과 Secret
- Resource Management (requests/limits)
- 헬스체크 (Liveness/Readiness Probe)
- 롤링 업데이트와 롤백

---

## 참고 자료

- [Kubernetes Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [Dynamic Volume Provisioning](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/)
