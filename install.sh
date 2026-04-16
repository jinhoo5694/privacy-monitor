#!/usr/bin/env bash
# privacy-monitor installer
# Usage: curl -fsSL https://raw.githubusercontent.com/jinhoo5694/privacy-monitor/main/install.sh | bash
set -euo pipefail

REPO="jinhoo5694/privacy-monitor"
BRANCH="main"
DEST="$HOME/.hammerspoon/privacy-shield"
HS_DIR="$HOME/.hammerspoon"
HS_INIT="$HS_DIR/init.lua"
LOADER_TAG="-- [privacy-shield]"
LOADER_LINE="dofile(hs.configdir .. \"/privacy-shield/init.lua\") $LOADER_TAG"

c_red()   { printf "\033[31m%s\033[0m\n" "$*"; }
c_green() { printf "\033[32m%s\033[0m\n" "$*"; }
c_blue()  { printf "\033[34m%s\033[0m\n" "$*"; }

if [[ "$(uname)" != "Darwin" ]]; then
    c_red "This installer only runs on macOS."
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    c_blue "Homebrew를 찾을 수 없어 설치합니다…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Apple Silicon brew path
    if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

if [ ! -d "/Applications/Hammerspoon.app" ]; then
    c_blue "Hammerspoon 설치 중…"
    brew install --cask hammerspoon
fi

c_blue "privacy-monitor 다운로드 중…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz" \
    | tar -xz -C "$TMP"
SRC="$TMP/privacy-monitor-${BRANCH}"

mkdir -p "$DEST/images"
cp "$SRC/init.lua" "$DEST/init.lua"
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$DEST/README.md"

# 이미지: 기존에 없는 파일만 복사 (사용자 커스텀 유지)
if [ -d "$SRC/images" ]; then
    for f in "$SRC/images"/*; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        if [ ! -f "$DEST/images/$name" ]; then
            cp "$f" "$DEST/images/$name"
        fi
    done
fi

mkdir -p "$HS_DIR"
if [ -f "$HS_INIT" ]; then
    if ! grep -qF "$LOADER_TAG" "$HS_INIT"; then
        printf '\n%s\n' "$LOADER_LINE" >> "$HS_INIT"
    fi
else
    echo "$LOADER_LINE" > "$HS_INIT"
fi

open -a Hammerspoon 2>/dev/null || true
sleep 1
osascript -e 'tell application "Hammerspoon" to reload' 2>/dev/null || true

c_green "✓ Privacy Shield 설치 완료!"
cat <<EOF

다음 단계:
  1. Hammerspoon이 접근성 권한을 요청하면 허용
     (시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용)
  2. ⌃⌥⌘H 로 온/오프 토글
  3. 이미지 추가: $DEST/images/

제거:
  curl -fsSL https://raw.githubusercontent.com/${REPO}/${BRANCH}/uninstall.sh | bash
EOF
