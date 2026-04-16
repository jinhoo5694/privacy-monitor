# privacy-monitor

모니터 훔쳐보는 동료 퇴치용 Hammerspoon 스크립트.

`⌃⌥⌘H` 한 번 누르면:
- iTerm2 빼고 모든 앱 창을 숨김
- 두 번째 모니터에 이미지들을 흩뿌려 전시하고 사망선고 문구 출력

다시 누르면 원상복구.

## 설치 (macOS)

터미널에 한 줄 붙여넣기:

```sh
curl -fsSL https://raw.githubusercontent.com/jinhoo5694/privacy-monitor/main/install.sh | bash
```

설치 스크립트가 자동으로 처리합니다:
- Homebrew 없으면 설치
- Hammerspoon 없으면 설치 (`brew install --cask hammerspoon`)
- `~/.hammerspoon/privacy-shield/`에 스크립트 복사
- `~/.hammerspoon/init.lua`에 로더 한 줄 추가 (기존 설정 보존)
- Hammerspoon 자동 실행 및 설정 리로드

설치 후 Hammerspoon이 **접근성(Accessibility) 권한**을 요청하면 허용해야 동작합니다.
(시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용)

## 사용법

- **토글**: `⌃⌥⌘H` (Control + Option + Command + H)
- **이미지 교체**: `~/.hammerspoon/privacy-shield/images/` 폴더에 본인 이미지를 넣으세요.
  - 지원 확장자: `.png .jpg .jpeg .gif .heic .bmp .webp`
  - GIF는 애니메이션 그대로 재생됩니다.
  - 파일 이름이 알파벳 순으로 정렬되니 `01_`, `02_` 같은 접두사로 순서 제어 가능.
  - 이미지는 충돌 없이 격자 + 랜덤 지터로 흩뿌려 배치됩니다.

## 커스터마이즈

`~/.hammerspoon/privacy-shield/init.lua` 상단 상수를 수정:

- `MODS`, `KEY` — 단축키
- `KEEP_APP` — 숨기지 않을 앱 (기본 `"iTerm2"`)
- `MESSAGE`, `EMOJI` — 두 번째 모니터에 띄울 문구/이모지
- `IMAGES_DIR` — 이미지 폴더 이름

수정 후 Hammerspoon 메뉴바 아이콘 → **Reload Config**.

## 제거

```sh
curl -fsSL https://raw.githubusercontent.com/jinhoo5694/privacy-monitor/main/uninstall.sh | bash
```

`~/.hammerspoon/privacy-shield/` 삭제 + `~/.hammerspoon/init.lua`에서 로더 한 줄 제거.
Hammerspoon 본체와 Homebrew는 그대로 둡니다.

## 주의

- `⌃⌥⌘H`는 macOS 기본 단축키와 겹치지 않지만, 다른 앱에서 쓰고 있다면 `init.lua`의 `KEY`를 바꾸세요.
- 두 번째 모니터가 없으면 토글 시 "no second monitor detected" 알림만 뜨고 아무 일도 일어나지 않습니다.
