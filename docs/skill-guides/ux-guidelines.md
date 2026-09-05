# ux-guidelines

## 한 줄 요약

셸 스크립트의 사용자 대면 출력을 감사하는 게 아니라 **직접 고칩니다**. raw
`echo`/`printf`/ANSI 이스케이프를 `ux_header`·`ux_section`·`ux_bullet` 같은 semantic
`ux_lib` 호출로 치환한 **재작성된 셸 스크립트**가 산출물입니다. 규칙의 SSOT 는
`shell-common/tools/ux_lib/UX_GUIDELINES.md`, 이 스킬은 그 규칙의 실행자입니다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때**

- `*_help()` 같은 help 함수를 `cat <<EOF` 덩어리에서 `ux_*` 호출로 옮길 때
- 진단 스크립트의 성공/경고/실패 메시지를 semantic 함수로 정리할 때
- `/authoring:sh-check` 의 Check 7(UX Lib Usage)이 FAIL 로 지적한 파일을 실제로 고칠 때
- `shell-common/**/*.sh` 전체를 UX 위반 관점으로 훑어 리뷰 문서를 낼 때 (Mode B)

**쓰지 않을 때** — 대상 파일이나 목적이 다르면 형제 스킬로 보냅니다.

| 상황 | 담당 | 비고 |
|------|------|------|
| `*.sh` 를 **판정만** 하고 싶을 때 | `/authoring:sh-check` | 읽기 전용 10개 기준 감사. 이 스킬은 그 진단의 치료 쪽 |
| `SKILL.md` 구조·설명 예산 점검 | `/authoring:skill-check` | 셸이 아니라 스킬 문서 |
| `SKILL.md` 100줄 초과 축소 | `/authoring:skill-refactor` | 마크다운 리팩터링 |
| `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` | `/harness:ai-context` | AI 컨텍스트 문서 전용 |

핵심 경계는 첫 줄입니다. `sh-check` 는 raw `echo` 를 **지적**하고 `ux-guidelines` 는
그 지적을 **코드로 반영**합니다 — 진단 → 치료 순서가 정상 흐름입니다.

## 호출 형식과 인자/옵션

```
/authoring:ux-guidelines [target]
/authoring:ux-guidelines help
```

`references/help.md` 가 인자의 SSOT 이며 문서화된 것은 이게 전부입니다.

| 인자/옵션 | 의미 |
|-----------|------|
| `[target]` | `UX_GUIDELINES.md` 기준에 맞출 함수·모듈·glob. 생략하면 **되묻습니다** |
| `help` | `references/help.md` 를 그대로 출력하고 중단. 파일을 읽지도 쓰지도 않음 |

`--fix`·`--apply`·`--dry-run` 같은 플래그는 없습니다. Mode A 는 기본이 쓰기, Mode B 는 읽기입니다.

**Mode A — 개별 함수 리팩터링.** 함수/모듈 하나가 대상이고 그 파일을 편집합니다.
`references/refactoring-playbook.md` 를 읽고 수행하며, **첫 실패에서 멈추고 보고**합니다.

**Mode B — 일괄 준수 점검.** `shell-common/**/*.sh` 전체가 대상. 코드를 고치지 않고
`docs/abc-review-C.md`(Claude) / `-CX.md`(ChatGPT) / `-G.md`(Gemini) 중 요청된 경로에
`high`/`medium`/`low` 심각도별 리뷰 문서를 씁니다. 감사 모드이므로 **첫 위반에서
멈추지 않고 전부** 보고합니다 — `references/bulk-review-workflow.md` 참고.

편집 전에 두 모드 중 하나를 명시적으로 고르는 것이 SKILL.md 의 첫 요구사항입니다.

## 동작 단계 요약 (Mode A)

1. 대상 모듈을 읽고 하드코딩된 출력 패턴을 찾습니다 — `cat <<EOF`, ANSI 코드, raw 상태 문자열.
2. 섹션 맵을 만듭니다 — header / 그룹된 커맨드 / 절차 / 경고 / 팁.
3. 승인된 조건부 패턴으로 `ux_lib` 로딩을 보장합니다.
4. 하드코딩 출력을 semantic 함수로 치환합니다. **동작은 그대로 두고 표현만** 바꿉니다.
5. bash 와 zsh 양쪽에서 검증하고 help 함수를 직접 호출해 봅니다.
6. 파일 경로 · 주요 치환 · 검증 결과를 보고합니다.

### 매핑 표 (raw 패턴 → `ux_lib` 호출)

`references/ux-foundation.md` 의 색 의미론과 함수 선택 규칙에서 나온 대응입니다.
함수명은 `shell-common/tools/ux_lib/ux_lib.sh` 의 실제 정의(총 28개)와 대조했습니다.

| raw 패턴 | 치환 | 근거 |
|----------|------|------|
| `cat <<EOF` help 블록 | `ux_header` + `ux_section` + `ux_bullet` | 하드코딩 help 블록은 high 심각도 위반 |
| `echo "=== Title ==="` / 수동 밑줄 | `ux_header` (제목), `ux_section` (구획) | Primary — header/section framing |
| `echo -e "${COLOR_RED}Error${COLOR_RESET}"` | `ux_error` | ANSI 직접 사용 금지. `ux_error` 는 stderr 로 나감 |
| `echo "Warning: ..."` | `ux_warning` | Warning — 주의·확인 지점 |
| `echo "Done"` / `echo "OK"` | `ux_success` | 비-semantic 메시지 금지 |
| `echo "Note: ..."` / 안내 문구 | `ux_info` | Info — 비긴급 안내 |
| `echo "  - item"` 짧은 커맨드 참조 | `ux_bullet` (하위 항목은 `ux_bullet_sub`) | 짧은 커맨드 참조는 bullet |
| `echo "1. step"` 순서 있는 절차 | `ux_numbered "1" "..."` | 순서 절차는 numbered |
| `printf "%-20s %s\n"` 고정 열 | `ux_table_header` / `ux_table_row` | 열이 안정적이면 table |
| `echo "-----"` 구분선 | `ux_divider` / `ux_divider_thick` | Muted — 구분선 |
| `read -p "..."` 확인 프롬프트 | `ux_confirm` / `ux_input` / `ux_menu` | 위험 작업은 명시적 확인 |
| 논리 블록 사이 빈 줄 | `echo ""` 유지 | 시각적 간격은 raw `echo ""` 허용 |

`ux_step`·`ux_usage`·`ux_require`·`ux_spinner` 처럼 실제 라이브러리에는 있지만
`references/ux-foundation.md` 카탈로그에는 빠진 함수가 있습니다. 카탈로그 대신
대상 환경의 `ux_lib.sh` 를 직접 grep 해 존재를 확인하십시오.

## 주의사항/제약

- **이 스킬은 파일을 씁니다.** `sh-check`/`skill-check` 와 달리 읽기 전용 계약이
  아닙니다. Mode A 는 대상 스크립트를 직접 편집하고, Mode B 는 리뷰 문서를 만듭니다.
  커밋은 명시적으로 요청받았을 때만 합니다.
- **`ux_lib` 가 로드돼 있어야 합니다.** playbook 의 승인된 조건부 로딩 패턴은
  `declare -f` / `source` 를 쓰는 **bash 문법**입니다. 대상이 `#!/bin/sh` 면
  `command -v ux_header` / `.` 로 바꿔야 합니다.
- **`set -eu` 스크립트는 로딩 구간을 감싸야 합니다.** `ux_lib.sh` 는 셸 판별에
  `$BASH_VERSION` / `$ZSH_VERSION` 을 미설정 상태로 읽으므로 `set -u` 아래에서
  source 하면 그 자리에서 죽습니다. 로딩 구간만 `set +u` / `set -u` 로 감싸십시오.
- **없는 경로에 `.` 을 걸지 마십시오.** dash 는 `|| true` 를 무시하고 셸을
  종료합니다. source 전에 `[ -r "$path" ]` 로 존재를 확인하고, `ux_lib` 가 없을 수
  있는 환경이면 최소 폴백 정의를 함께 두어 동작을 보존하십시오.
- **리팩터링 후 반드시 구문 검사.** `bash -n`, `zsh -n`(POSIX 대상이면 `dash -n`)
  을 돌리고, 가능하면 실제로 실행해 종료 코드와 stdout/stderr 분리가 리팩터링 전과
  같은지 대조하십시오. `ux_error` 는 stderr, `ux_warning`/`ux_success` 는 stdout 입니다.
- **호출부에 이모지를 새로 넣지 마십시오.** `ux_success` 계열이 런타임에 글리프를
  찍는 것은 라이브러리 내부 구현이고, 규칙은 호출부에 적용됩니다.
- **동작 변경 금지가 기본값.** 표현만 바꿉니다. 종료 코드, stderr 라우팅, 출력의
  기계 파싱 가능성(CI 가 grep 하는 줄 등)이 바뀌면 리팩터링이 아니라 회귀입니다.
