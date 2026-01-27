#!/bin/bash
#
# Git hooks 설치 스크립트
# 이 스크립트는 프로젝트 clone 후 한 번만 실행하면 됩니다.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "🔧 Git hooks 설치 중..."

# pre-commit hook 생성
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
#
# pre-commit hook
# versions.yaml이 변경되면 자동으로 모든 파일의 버전 정보를 업데이트합니다.
#

# versions.yaml이 staging area에 있는지 확인
if git diff --cached --name-only | grep -q "^versions.yaml$"; then
    echo "📦 versions.yaml 변경 감지 - 버전 정보 업데이트 중..."

    # 환경 변수 설정 (스크립트에서 git add 수행하도록)
    export GIT_HOOK=1

    # Python 스크립트 실행
    if command -v python3 &> /dev/null; then
        python3 "$(git rev-parse --show-toplevel)/scripts/update-versions.py"
    else
        echo "⚠️  Warning: python3가 설치되어 있지 않습니다."
        echo "   수동으로 실행하세요: python3 scripts/update-versions.py"
    fi
fi

exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ pre-commit hook 설치 완료"
echo ""
echo "사용 방법:"
echo "  1. versions.yaml 파일의 버전 정보 수정"
echo "  2. git add versions.yaml"
echo "  3. git commit -m \"chore: 버전 업데이트\""
echo "     → 자동으로 모든 파일이 업데이트됩니다!"
echo ""
echo "수동 실행:"
echo "  python3 scripts/update-versions.py"
echo ""
