# Scripts

프로젝트 관리용 스크립트 모음입니다.

---

## 버전 관리 시스템

이 프로젝트는 `versions.yaml` 파일로 모든 버전 정보를 중앙 관리합니다.

### 파일 구조

```
miribit-k8s-study/
├── versions.yaml              # 버전 정보 정의 (이 파일만 수정)
└── scripts/
    ├── update-versions.py     # 버전 업데이트 스크립트
    └── install-hooks.sh       # Git hook 설치 스크립트
```

---

## 초기 설정 (최초 1회)

프로젝트를 clone한 후 아래 명령어를 실행하세요:

```bash
# Git hook 설치
bash scripts/install-hooks.sh
```

이후 `versions.yaml` 변경 시 자동으로 모든 파일이 업데이트됩니다.

### 요구사항

- Python 3.x
- PyYAML 라이브러리

```bash
# PyYAML 설치 (없는 경우)
pip3 install pyyaml
```

---

## 사용 방법

### 버전 업데이트 (권장)

1. `versions.yaml` 파일 수정:

```yaml
# versions.yaml
kubernetes: "1.36"      # 예: 1.35 → 1.36
containerd: "2.3.0"     # 예: 2.2.1 → 2.3.0
cilium: "1.19.0"        # 예: 1.18.6 → 1.19.0
minikube: "1.38.0"      # 예: 1.37.0 → 1.38.0
```

2. 커밋:

```bash
git add versions.yaml
git commit -m "chore: Kubernetes 1.35 버전 업데이트"
```

3. 끝! pre-commit hook이 자동으로 모든 파일을 업데이트합니다.

### 수동 실행

hook 없이 직접 실행하려면:

```bash
python3 scripts/update-versions.py
```

---

## versions.yaml 구조

```yaml
# 핵심 컴포넌트
kubernetes: "1.35"        # Kubernetes 버전
containerd: "2.2.1"       # Container Runtime 버전
cilium: "1.18.6"          # CNI 플러그인 버전
minikube: "1.37.0"        # Minikube 버전

# 운영체제
ubuntu: "24.04"           # Ubuntu 버전

# 컨테이너 이미지
nginx: "1.27"             # nginx 이미지 태그
mysql: "8.0"              # mysql 이미지 태그
busybox: "1.36"           # busybox 이미지 태그
redis: "7"                # redis 이미지 태그

# 추가 도구
runc: "1.2.3"             # runc 버전
cni_plugins: "1.6.1"      # CNI 플러그인 버전

# 메타 정보 (문서용)
kubernetes_codename: "Timbernetes"    # K8s 릴리즈 코드명
kubernetes_release_date: "2025.12"    # K8s 릴리즈 날짜
```

---

## 업데이트 대상 파일

스크립트는 다음 확장자의 파일을 자동 업데이트합니다:

- `.md` - 마크다운 문서
- `.yaml`, `.yml` - YAML 설정 파일
- `.sh` - 셸 스크립트

### 제외 항목

- `versions.yaml` (버전 정의 파일 자체)
- `.git/` 디렉토리
- `node_modules/`, `venv/` 등 의존성 디렉토리

---

## 지원하는 버전 패턴

스크립트가 인식하는 패턴 예시:

| 패턴 | 예시 |
|------|------|
| Kubernetes 버전 | `Kubernetes v1.35`, `kubernetes 1.35` |
| apt 저장소 | `/stable:/v1.35/deb/` |
| Containerd | `CONTAINERD_VERSION="2.2.1"`, `containerd-2.2.1-linux` |
| Cilium | `cilium install --version 1.18.6` |
| Minikube | `minikube v1.37.0`, `Minikube v1.37.0` |
| 컨테이너 이미지 | `nginx:1.27`, `mysql:8.0`, `busybox:1.36` |

---

## 문제 해결

### hook이 실행되지 않음

```bash
# hook 재설치
bash scripts/install-hooks.sh

# 실행 권한 확인
ls -la .git/hooks/pre-commit
```

### 특정 파일이 업데이트되지 않음

새로운 버전 패턴이 필요할 수 있습니다. `scripts/update-versions.py`의 `get_replacement_patterns()` 함수에 패턴을 추가하세요.

### PyYAML 에러

```bash
pip3 install pyyaml
```

---

## 스크립트 상세

### install-hooks.sh

Git pre-commit hook을 설치합니다.

```bash
bash scripts/install-hooks.sh
```

- `.git/hooks/pre-commit` 파일 생성
- `versions.yaml` 변경 감지 시 자동으로 `update-versions.py` 실행

### update-versions.py

모든 파일의 버전 정보를 업데이트합니다.

```bash
python3 scripts/update-versions.py
```

- `versions.yaml`에서 버전 정보 로드
- 정규식으로 파일 내 버전 패턴 검색 및 교체
- 변경된 파일 목록 출력
