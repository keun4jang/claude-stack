# claude-stack

rmsdu의 Claude Code 스택을 **어느 기기에서든 재현**하기 위한 저장소.

내용물을 저장하는 곳이 아니라 **레시피**를 담는 곳입니다. 스킬과 플러그인 원본은 전부 공개 GitHub 저장소에 있고, 여기엔 "무엇을 어디서 가져올지"만 있습니다. 그래서 전체 크기가 수십 KB입니다.

## 무엇이 들어 있나

| 경로 | 용도 |
|---|---|
| `.claude-plugin/marketplace.json` | 이 저장소를 Claude Code 마켓플레이스로 만드는 파일 |
| `plugins/my-stack/` | 5개를 한 번에 설치하는 번들 플러그인 (`dependencies`만 선언) |
| `bootstrap.ps1` | 새 PC 자동 설정 스크립트 |
| `dotfiles/settings.json` | 플러그인 외 설정 (권한 설정은 의도적으로 제외) |
| `dotfiles/skills-lock.json` | 스킬 55개의 출처 저장소 + 해시 기록 |
| `examples/project-claude-settings.json` | 클라우드/모바일용 — 프로젝트 저장소에 커밋할 설정 |

## 새 PC에서 설치

```powershell
git clone https://github.com/rmsdu/claude-stack
cd claude-stack
.\bootstrap.ps1
```

스크립트 없이 직접 하려면 명령 2개면 됩니다:

```powershell
claude plugin marketplace add rmsdu/claude-stack
claude plugin install my-stack@rmsdu-stack
```

설치되는 것 (실제 검증 완료):

```
√ Successfully installed plugin: my-stack@rmsdu-stack (scope: user)
  (+ 5 dependencies: claude-mem, superpowers, ui-ux-pro-max,
                     marketing-skills, remotion-skills)
```

## 두 가지 경로 — 반드시 하나만

스킬을 넣는 방법이 두 가지고, **둘 다 하면 모든 스킬이 두 번 로드**됩니다.

| | marketplace 경로 (기본) | classic 경로 |
|---|---|---|
| 명령 수 | 2개 | 7개 |
| 스킬 이름 | `marketing-skills:cro` | `cro` |
| 버전 고정 | 가능 (태그 있는 저장소만) | 불가 (항상 HEAD) |
| Remotion 스킬 | 9개 (`remotion-docs` 포함) | 8개 |

```powershell
.\bootstrap.ps1                  # marketplace
.\bootstrap.ps1 -Route classic   # 기존 방식 (npx skills)
```

## 세션당 토큰 비용

전체 스택은 **매 세션 11,112 토큰**을 상시 점유합니다. 실측치:

| 플러그인 | 상시 토큰 |
|---|---:|
| marketing-skills | 8,381 |
| claude-mem | 1,193 |
| ui-ux-pro-max | 741 |
| superpowers | 608 |
| remotion-skills | 189 |
| **합계** | **11,112** |

marketing-skills가 75%입니다. 마케팅 작업을 안 하는 프로젝트에서는 번들 대신 필요한 것만 개별 설치하는 편이 낫습니다:

```powershell
claude plugin install ui-ux-pro-max@rmsdu-stack
claude plugin install superpowers@rmsdu-stack
```

## 클라우드 / 모바일에서 쓰려면

PC를 켜두고 폰에서 쓸 거라면 이 저장소가 필요 없습니다 — Remote Control이 폰을 PC 세션의 창으로 만들어 주므로 5개가 그대로 작동합니다:

```powershell
claude remote-control    # 스페이스바 = QR 코드
```

**PC 없이** 클라우드 세션(claude.ai/code, 모바일 Code 탭)에서 쓰려면 `examples/project-claude-settings.json`을 각 프로젝트 저장소의 `.claude/settings.json`으로 커밋하세요. 클라우드 세션은 저장소만 읽고 `~/.claude`는 절대 읽지 않습니다. 선언된 플러그인은 세션 시작 시 자동 설치됩니다.

## 여기에 절대 넣지 말 것

`.gitignore`에 명시돼 있지만 이유를 남겨둡니다:

- **`.credentials.json`** — Claude 계정 OAuth 토큰 + 연결된 MCP 서버 토큰. 유출 시 계정 탈취.
- **`settings.local.json`** — SSH 키 경로, 서버 IP, 절대 경로가 박혀 있음. 이식도 안 됨.
- **`plugins/`** — 537 MB 캐시. `claude plugin install`이 다시 받음.
- **`projects/`, `history.jsonl`** — 과거 대화 전문.
- **`~/.claude/skills/`** — Windows 정션. 절대 경로를 가리켜서 다른 기기에서 무의미.

새 기기 로그인은 `claude auth login`으로 따로 하세요. 자격증명은 이 저장소에 들어가지 않습니다.

`dotfiles/settings.json`에는 원본에 있던 `permissions.defaultMode: bypassPermissions`와
`skipDangerousModePermissionPrompt`를 **일부러 뺐습니다.** git clone 한 번으로 모든 명령이
확인 없이 실행되는 상태가 되는 건 위험합니다. 필요하면 새 기기에서 직접 켜세요.

## 유지보수

```powershell
# 스택에 도구 추가: marketplace.json에 항목 추가 + plugin.json의 dependencies에 이름 추가
#                   + my-stack version 올리고 push
claude plugin update my-stack        # 사용자 측
# 그다음 /reload-plugins

# marketplace.json 문법 검사
claude plugin validate . --strict
```

### 버전 고정에 대한 사실

`dependencies`의 버전 제약은 `{plugin-name}--v{version}` git 태그로 해석됩니다.

- `coreyhaines31/marketingskills` — 태그 있음 (설치 시 `2.8.12`로 해석됨). 고정 가능.
- `remotion-dev/skills` — **태그 없음**. 커밋 SHA(`ab22f5fa8996`)로 잡히며 항상 기본 브랜치를 따라감. 고정 불가.
- `dotfiles/skills-lock.json`도 `ref`가 하나도 없어 마찬가지로 HEAD를 따라갑니다.
