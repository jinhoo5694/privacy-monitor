#!/usr/bin/env bash
# privacy-monitor uninstaller
set -euo pipefail

DEST="$HOME/.hammerspoon/privacy-shield"
HS_INIT="$HOME/.hammerspoon/init.lua"
LOADER_TAG="-- [privacy-shield]"

if [ -f "$HS_INIT" ]; then
    grep -v -F "$LOADER_TAG" "$HS_INIT" > "${HS_INIT}.tmp" || true
    mv "${HS_INIT}.tmp" "$HS_INIT"
fi

rm -rf "$DEST"

osascript -e 'tell application "Hammerspoon" to reload' 2>/dev/null || true

echo "✓ Privacy Shield — EVA — 제거 완료."
echo "  Hammerspoon과 Homebrew는 그대로 둡니다 — 필요하면 직접 제거하세요."
