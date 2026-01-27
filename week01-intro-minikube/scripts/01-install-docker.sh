#!/bin/bash
# Docker 설치 스크립트 for Ubuntu 24.04
# 사용법: sudo bash 01-install-docker.sh

set -e

echo "=== Docker 설치 스크립트 ==="
echo "Ubuntu 24.04 기준"
echo ""

# 기존 Docker 패키지 제거
echo "[1/5] 기존 Docker 패키지 제거..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg 2>/dev/null || true
done

# 필수 패키지 설치
echo "[2/5] 필수 패키지 설치..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Docker GPG 키 추가
echo "[3/5] Docker GPG 키 추가..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Docker 저장소 추가
echo "[4/5] Docker 저장소 추가..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker 설치
echo "[5/5] Docker 설치..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 현재 사용자를 docker 그룹에 추가
echo ""
echo "=== 사용자 권한 설정 ==="
TARGET_USER="${SUDO_USER:-$USER}"
sudo usermod -aG docker "$TARGET_USER"

echo ""
echo "=== Docker 설치 완료 ==="
docker --version
echo ""
echo "주의: docker 그룹 권한을 적용하려면 다음 명령어를 실행하거나 재로그인하세요:"
echo "  newgrp docker"
echo ""
echo "설치 확인:"
echo "  docker run hello-world"
