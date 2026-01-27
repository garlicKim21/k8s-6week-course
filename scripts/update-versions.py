#!/usr/bin/env python3
"""
버전 정보 자동 업데이트 스크립트

versions.yaml의 버전 정보를 읽어 프로젝트 내 모든 파일을 업데이트합니다.

사용법:
    python3 scripts/update-versions.py

pre-commit hook에서 자동 실행됩니다.
"""

import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML이 필요합니다. 설치하세요: pip3 install pyyaml")
    sys.exit(1)

# 프로젝트 루트 디렉토리
PROJECT_ROOT = Path(__file__).parent.parent

# 버전 파일 경로
VERSIONS_FILE = PROJECT_ROOT / "versions.yaml"


def load_versions():
    """versions.yaml 파일에서 버전 정보를 로드합니다."""
    with open(VERSIONS_FILE, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def get_replacement_patterns(versions):
    """
    버전 교체 패턴을 생성합니다.
    (정규식 패턴, 교체 문자열) 튜플 리스트를 반환합니다.
    """
    k8s = versions["kubernetes"]
    containerd = versions["containerd"]
    cilium = versions["cilium"]
    minikube = versions["minikube"]
    ubuntu = versions["ubuntu"]
    nginx = versions["nginx"]
    mysql = versions["mysql"]
    busybox = versions["busybox"]
    redis = versions["redis"]
    runc = versions["runc"]
    cni = versions["cni_plugins"]
    codename = versions.get("kubernetes_codename", "")
    release_date = versions.get("kubernetes_release_date", "")

    patterns = [
        # ===== Kubernetes =====
        # v1.XX 형식 (1.로 시작하는 버전)
        (r"(Kubernetes\s+v?)1\.\d+(\.\d+)?", rf"\g<1>{k8s}"),
        (r"(kubernetesVersion:\s*v?)1\.\d+(\.\d+)?", rf"\g<1>{k8s}.0"),
        (r"(kubernetes\s+)1\.\d+(\.\d+)?", rf"\g<1>{k8s}"),
        (r"(K8s\s+)1\.\d+(\.\d+)?", rf"\g<1>{k8s}"),
        # apt 저장소 URL
        (r"(/stable:/v)1\.\d+(/deb/)", rf"\g<1>{k8s}\2"),

        # ===== Containerd =====
        (r'(CONTAINERD_VERSION=")[\d.]+(")', rf"\g<1>{containerd}\2"),
        (r"(containerd-)\d+\.\d+\.\d+(-linux)", rf"\g<1>{containerd}\2"),
        (r"(Containerd\s+)\d+\.\d+\.\d+", rf"\g<1>{containerd}"),
        (r"(containerd\s+)\d+\.\d+\.\d+", rf"\g<1>{containerd}"),
        (r"(containerd\s*\|\s*v?)\d+\.\d+\.\d+", rf"\g<1>{containerd}"),

        # ===== Cilium =====
        (r"(cilium install --version\s+)\d+\.\d+\.\d+", rf"\g<1>{cilium}"),
        (r'(CILIUM_VERSION=")[\d.]+(")', rf"\g<1>{cilium}\2"),
        (r"(Cilium\s+v?)\d+\.\d+\.\d+", rf"\g<1>{cilium}"),
        (r"(cilium\s*\|\s*v?)\d+\.\d+\.\d+", rf"\g<1>{cilium}"),

        # ===== Minikube =====
        (r"(Minikube\s*\|\s*v?)\d+\.\d+\.\d+", rf"\g<1>{minikube}"),  # 테이블: | Minikube | v1.36.0 |
        (r"(Minikube\s+v?)\d+\.\d+\.\d+", rf"\g<1>{minikube}"),       # Minikube v1.36.0
        (r"(minikube\s+v)\d+\.\d+\.\d+", rf"\g<1>{minikube}"),        # minikube v1.36.0
        (r"(minikube-)\d+\.\d+\.\d+", rf"\g<1>{minikube}"),           # minikube-1.36.0

        # ===== Ubuntu =====
        (r"(Ubuntu\s+)\d+\.\d+", rf"\g<1>{ubuntu}"),
        (r"(ubuntu\s*\|\s*)\d+\.\d+", rf"\g<1>{ubuntu}"),

        # ===== Container Images =====
        (r"(nginx:)\d+\.\d+", rf"\g<1>{nginx}"),
        (r"(mysql:)\d+\.\d+", rf"\g<1>{mysql}"),
        (r"(busybox:)\d+\.\d+", rf"\g<1>{busybox}"),
        (r"(redis:)\d+", rf"\g<1>{redis}"),

        # ===== Additional Tools =====
        (r'(RUNC_VERSION=")[\d.]+(")', rf"\g<1>{runc}\2"),
        (r'(CNI_PLUGINS_VERSION=")[\d.]+(")', rf"\g<1>{cni}\2"),
        (r"(cni-plugins-linux-amd64-v)\d+\.\d+\.\d+", rf"\g<1>{cni}"),

        # ===== Kubernetes Codename (문서용) =====
        (r'("Timbernetes"|"[A-Z][a-z]+netes")', f'"{codename}"'),
        (r"(\()(20\d{2}\.\d{1,2})(\s+릴리즈\))", rf"\g<1>{release_date}\3"),
    ]

    return patterns


def update_file(filepath, patterns):
    """
    파일 내용에서 버전 패턴을 교체합니다.
    변경이 있으면 True, 없으면 False를 반환합니다.
    """
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except (UnicodeDecodeError, IOError):
        return False

    original_content = content

    for pattern, replacement in patterns:
        content = re.sub(pattern, replacement, content)

    if content != original_content:
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        return True

    return False


def find_target_files():
    """업데이트 대상 파일들을 찾습니다."""
    target_extensions = {".md", ".yaml", ".yml", ".sh"}
    exclude_dirs = {".git", ".venv", "venv", "__pycache__", "node_modules"}
    exclude_files = {"versions.yaml"}  # 버전 정의 파일 자체는 제외

    target_files = []

    for root, dirs, files in os.walk(PROJECT_ROOT):
        # 제외 디렉토리 스킵
        dirs[:] = [d for d in dirs if d not in exclude_dirs]

        for file in files:
            if file in exclude_files:
                continue

            filepath = Path(root) / file
            if filepath.suffix in target_extensions:
                target_files.append(filepath)

    return target_files


def main():
    """메인 함수"""
    print("🔄 버전 정보 업데이트 시작...")

    # 버전 정보 로드
    if not VERSIONS_FILE.exists():
        print(f"❌ Error: {VERSIONS_FILE} 파일을 찾을 수 없습니다.")
        sys.exit(1)

    versions = load_versions()
    print(f"📦 버전 정보 로드 완료:")
    print(f"   - Kubernetes: {versions['kubernetes']}")
    print(f"   - Containerd: {versions['containerd']}")
    print(f"   - Cilium: {versions['cilium']}")
    print(f"   - Minikube: {versions['minikube']}")

    # 교체 패턴 생성
    patterns = get_replacement_patterns(versions)

    # 대상 파일 찾기
    target_files = find_target_files()
    print(f"\n📁 대상 파일: {len(target_files)}개")

    # 파일 업데이트
    updated_files = []
    for filepath in target_files:
        if update_file(filepath, patterns):
            updated_files.append(filepath)

    # 결과 출력
    if updated_files:
        print(f"\n✅ 업데이트된 파일: {len(updated_files)}개")
        for f in updated_files:
            rel_path = f.relative_to(PROJECT_ROOT)
            print(f"   - {rel_path}")

        # Git staging (pre-commit hook용)
        if os.environ.get("GIT_HOOK"):
            import subprocess
            for f in updated_files:
                subprocess.run(["git", "add", str(f)], cwd=PROJECT_ROOT)
            print("\n📌 변경된 파일이 staging area에 추가되었습니다.")
    else:
        print("\n✨ 모든 파일이 최신 버전입니다.")

    print("\n🎉 완료!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
