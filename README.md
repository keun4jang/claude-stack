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
git clone https://github.com/keun4jang/claude-stack
cd claude-stack
.\bootstrap.ps1
```

스크립트 없이 직접 하려면 명령 2개면 됩니다:

```powershell
claude plugin marketplace add keun4jang/claude-stack
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

## 어디서든 자동으로 쓰기

먼저 알아야 할 사실: **모바일 앱은 자체 설정을 갖지 않습니다.** 공식 문서 원문 —

> "Mobile is a **thin client** into those same cloud sessions or into a local
> session via Remote Control, and can send tasks to Desktop with Dispatch."

즉 폰에 스킬을 "설치"하는 건 불가능합니다. 폰은 항상 **다른 곳에서 도는 세션의 창**입니다.
그래서 자동화 지점은 정확히 두 곳뿐입니다.

| 어디서 | 자동? | 어떻게 |
|---|---|---|
| 이 PC | ✅ | user scope |
| 다른 PC | 최초 1회 명령 2개 | 위 install 섹션 |
| 폰 — PC 켜둠 | ✅ **완전 자동** | `remoteControlAtStartup: true` |
| 클라우드 — PC 꺼짐, **저장소 무관** | ✅ 계정 1회 | claude.ai Skills 업로드 |
| 클라우드 — PC 꺼짐, 플러그인까지 | ✅ 저장소당 1회 | `.claude/settings.json` 커밋 |

### 폰 — PC 켜둠 (완전 자동)

`~/.claude/settings.json`에 이 세 줄이면 끝. 모든 세션이 자동으로 Remote Control에 연결되고,
폰 Claude 앱 → Code 탭에 뜹니다. 명령을 칠 필요가 없습니다.

```json
{
  "remoteControlAtStartup": true,
  "agentPushNotifEnabled": true,
  "inputNeededNotifEnabled": true
}
```

이 경로에선 5개가 전부 그대로 작동합니다 — 실행 주체가 PC이기 때문입니다.
Pro/Max/Team/Enterprise 필요, `claude auth login`으로 로그인돼 있어야 합니다.

> ⚠️ 켜져 있는 동안 **세션 전문(메시지·응답·도구 활동)이 Anthropic 서버에 저장**됩니다.
> 실행과 파일 접근은 로컬에 남지만 대화 기록은 아닙니다. 끄려면 `false`.

### 클라우드 — PC 꺼짐, 저장소 무관 (계정 1회) ⭐

**PC가 꺼져 있어도, 어느 저장소든, 그냥 대화만 해도 자동으로 적용되는 유일한 경로.**
공식 carry-over 표의 한 줄:

> `~/.claude/skills/` → No — "...**Skills you enable on claude.ai are loaded into
> cloud sessions automatically**"

claude.ai에 올린 스킬은 **모든 클라우드 세션에 자동 로드**됩니다. 커밋도, 저장소 설정도 필요 없습니다.

```powershell
.\make-claude-ai-zips.ps1            # 47개 개별 ZIP
.\make-claude-ai-zips.ps1 -Bundled   # 1개로 묶기 (업로드 1번)
```
그다음 **claude.ai → Settings → Features → Skills**에서 업로드. Pro/Max/Team/Enterprise +
code execution 활성화 필요.

**업로드는 수동일 수밖에 없습니다.** Skills API(`/v1/skills`)는 별개 저장소입니다 —
공식 문서: *"Skills uploaded through the API are not available on claude.ai."*
벌크 업로드도 GitHub 동기화도 없습니다.

| | 개별 47개 | 번들 1개 |
|---|---|---|
| 업로드 횟수 | 47 | **1** |
| 상시 토큰 | ~8,400 | **~200** |
| 자동 발동 | 스킬별 정밀 | 인덱스가 라우팅 |

번들은 SKILL.md 하나가 47개 인덱스 역할을 하고 필요한 것만 읽어 들입니다.
토큰이 40배 싸지만, 개별 description이 시스템 프롬프트에 없어 발동이 덜 정밀합니다.

**remotion 8개와 superpowers는 올리지 마세요.** 로컬 저장소·npm·git이 필요한데
claude.ai 샌드박스엔 없습니다. 스크립트가 자동으로 제외합니다.
(마케팅 47개는 전부 순수 마크다운이라 그대로 작동합니다.)

### 클라우드 — 플러그인까지 필요하면 (저장소당 1회)

claude.ai Skills는 *스킬*만 올립니다. 플러그인(claude-mem, ui-ux-pro-max 등)까지
클라우드에서 쓰려면 저장소에 선언해야 합니다. 클라우드 세션은 **저장소만** 읽습니다:

| | 클라우드에서? |
|---|---|
| `.claude/settings.json`에 선언된 플러그인 | **Yes** — "Installed at session start" |
| user 설정에만 있는 플러그인 | **No** |
| `~/.claude/skills/` | **No** — "Commit them to the repo's `.claude/` instead" |

> "To make your own configuration available in cloud sessions, **commit it to the repo**."

계정 단위 사용자 설정은 존재하지 않습니다. 저장소마다 한 번씩 넣으세요:

```powershell
.\add-to-repo.ps1 C:\Projects\my-app
# 그다음 git add .claude/settings.json && git commit && git push
```

기존 `.claude/settings.json`이 있으면 **덮어쓰지 않고 병합**합니다.
토큰을 아끼려면 필요한 것만:

```powershell
.\add-to-repo.ps1 . -Only ui-ux-pro-max,superpowers
```

커밋 후에는 그 저장소의 클라우드 세션이 시작 시 자동 설치합니다 — PC 불필요.
로컬에선 폴더 신뢰 시 설치 프롬프트가 한 번 뜹니다.

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
