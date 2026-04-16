# privacy-monitor — EVA edition

特務機関 NERV 테마. 모니터 훔쳐보는 동료에게 사도 요격 경보를 전시한다.

`⌃⌥⌘H` 한 번 누르면:
- iTerm2 빼고 모든 앱 창을 숨김
- 두 번째 모니터에 빨간 경고등 깜빡이며 **使徒迎撃中 / A.T.フィールド展開 / WARNING** 등 NERV 스타일 HUD 전시
- `images/eva/` 안의 이미지/GIF가 흩뿌려짐

다시 누르면 원상복구.

## 설치 (macOS)

```sh
curl -fsSL https://raw.githubusercontent.com/jinhoo5694/privacy-monitor/eva/install.sh | bash
```

자동 처리:
- Homebrew / Hammerspoon 없으면 설치
- `~/.hammerspoon/privacy-shield/` 에 스크립트 + 이미지 + 폰트 복사
- `~/.hammerspoon/init.lua` 에 로더 추가
- Hammerspoon 실행 및 리로드

설치 후 **접근성(Accessibility) 권한** 허용 필수.

## 폰트

현재 번들된 폰트: **Refrigerator Deluxe** (CC BY 4.0, via [OnlineWebFonts.com](http://www.onlinewebfonts.com)).
에반게리온 NERV UI의 영문 폰트로 널리 쓰이는 그 폰트입니다. 일본어는 시스템 Hiragino로 fallback.

다른 폰트로 교체하려면:
1. `~/.hammerspoon/privacy-shield/fonts/` 에 `.ttf / .otf / .woff / .woff2` 드롭
2. Hammerspoon 메뉴바 → **Reload Config**

`fonts/` 폴더의 첫 번째 폰트 파일이 `@font-face`의 `NERV` 패밀리로 자동 매핑됩니다.

## 이미지 추가/교체

`~/.hammerspoon/privacy-shield/images/eva/` 에 넣으세요.
- 지원: `.png .jpg .jpeg .gif .heic .bmp .webp`
- GIF는 애니메이션 재생
- 충돌 없는 grid + jitter 배치

## 커스터마이즈

`~/.hammerspoon/privacy-shield/init.lua` 상단 상수:
- `MODS`, `KEY` — 단축키
- `KEEP_APP` — 숨기지 않을 앱
- `IMAGES_DIR`, `FONTS_DIR` — 경로

HTML/CSS로 텍스트, 색깔, 애니메이션 전부 수정 가능 (`buildHTML` 함수 내부).

## 제거

```sh
curl -fsSL https://raw.githubusercontent.com/jinhoo5694/privacy-monitor/eva/uninstall.sh | bash
```
