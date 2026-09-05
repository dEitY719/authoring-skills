# sh-check

## 한 줄 요약

셸 스크립트(`*.sh`) 한 개를 dotfiles 품질 기준 10개 항목으로 감사하고,
PASS/WARN/FAIL/N-A 표 · Score · Verdict · Next Actions 로 구성된 **감사 리포트**를
출력합니다. 읽기 전용이라 대상 스크립트를 절대 수정하지 않습니다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때**

- `*.sh` / `*.bash` / `*.zsh` 파일 하나의 품질을 점검하고 싶을 때
- 리뷰나 PR 전에 "이 스크립트가 `git_worktree.sh` 수준인가"를 판정하고 싶을 때
- 고칠 목록을 WARN/FAIL 단위로 뽑아 다음 작업 티켓을 만들고 싶을 때

**쓰지 않을 때** — 감사 대상 파일 종류가 다르면 형제 스킬로 보냅니다.

| 대상 파일 | 담당 스킬 | 비고 |
|-----------|-----------|------|
| `SKILL.md` | `/authoring:skill-check` | 스킬 구조·설명 예산 16개 검사. sh-check 의 거울상 |
| `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` | `/harness:ai-context check` | AI 컨텍스트 문서 전용 |
| `*.sh` 의 help 텍스트를 **실제로 고쳐야** 할 때 | `/authoring:ux-guidelines` | raw `echo`/`printf`/ANSI 를 `ux_header`·`ux_section`·`ux_bullet` 같은 semantic `ux_lib` 호출로 치환 |

특히 마지막 줄이 핵심 경계입니다. sh-check 의 Check 7(UX Lib Usage)은 raw `echo`
를 **지적만** 합니다. 그 지적을 코드로 반영하는 쪽은 `ux-guidelines` 입니다.
sh-check 로 진단하고 → `ux-guidelines` 로 치료하는 순서가 정상 흐름입니다.

## 호출 형식과 인자/옵션

```
/authoring:sh-check [path/to/script.sh]
/authoring:sh-check help
```

`references/help.md` 가 인자 목록의 SSOT 이며, 실제로 문서화된 것은 다음이 전부입니다.

| 인자/옵션 | 의미 |
|-----------|------|
| `[path]` | 감사할 셸 스크립트 경로. **선택** |
| (인자 없음) | 현재 디렉터리에서 `*.sh` 탐색 — 1개면 자동 감사, 여러 개면 목록을 보여주고 되물음, 0개면 힌트 출력 |
| `-h`, `--help`, `help` | `references/help.md` 를 그대로 출력하고 **중단**. 검사 없음 |

`--fix`, `--apply`, `--json` 같은 플래그는 존재하지 않습니다. 쓰기 동작이 없으므로
dry-run 개념 자체가 없습니다.

## 동작 단계 요약

1. **파일 특정** — 경로 검증(확장자 아님 → 경고 후 계속), `LINES`(`wc -l`)와
   `IS_SOURCED` 판정. `shell-common/functions/`·`bash/`·`zsh/` 아래이거나 상단에
   `case $- in *i*)` 가 있으면 sourced fragment, 아니면 executable script 로 분류.
2. **10개 검사 수행** — `references/checks.md` 의 기준표와 grep 힌트를 사용해
   각 항목을 PASS / WARN / FAIL / N-A 로 판정.
3. **리포트 출력** — `references/report-template.md` 형식 그대로.
   Structure 표 + UX 표, `Score: X/10 checks passed (Y warnings, Z N/A)`,
   Verdict 한 줄, WARN/FAIL 마다 한 줄씩인 Next Actions.

### 10개 기준

**Structure (1-5)**

| # | 검사 | 보는 것 |
|---|------|---------|
| 1 | Shebang + POSIX Hygiene | 1행이 `#!/bin/sh`(권장) 또는 `#!/usr/bin/env bash`. `[[ ]]`·`&>/dev/null`·`declare`·`function name()` 같은 bashism 배제 |
| 2 | Interactive Guard | sourced 파일 상단의 `case $- in *i*) ;; *) [ -n "${DOTFILES_FORCE_INIT-}" ] \|\| return 0 ;; esac` |
| 3 | Section Anatomy | 공개 함수 앞의 `# ===…===` 배너 + `# Usage:` + `# Args:` |
| 4 | Naming Convention | 비공개 헬퍼는 `_prefix_`, 공개 함수는 접두사 없음, 전부 snake_case |
| 5 | ZSH Compat Guard | 양쪽 셸에 노출되는 함수 상단의 `[ -n "${ZSH_VERSION-}" ] && emulate -L sh` |

**UX Quality (6-10)**

| # | 검사 | 보는 것 |
|---|------|---------|
| 6 | Help Flag | `-h\|--help` 처리 → 구조화된 help 루틴 → 조기 `return 0`(실행 스크립트는 `exit 0`) |
| 7 | UX Lib Usage | 사용자 대면 출력이 `ux_header`/`ux_section`/`ux_info`/`ux_success`/`ux_warn`/`ux_error`/`ux_bullet`/`ux_table_row` 경유. raw `echo`·`printf`·`tput` 금지(`$()` 로 잡히는 반환값, `DEBUG` 가드 출력은 예외) |
| 8 | Input Validation | 필수 인자 검사, 상호배타 플래그 거부, unknown option 에서 help + 비정상 종료 |
| 9 | Verdict Output | 진단 함수가 명시적 `state:` 를 포함한 구조화된 key:value 판정 출력 |
| 10 | Next-action Hint | 성공 출력이 다음에 실행할 명령을 `next:` 한 줄로 제시 |

Verdict 는 `PASS_COUNT / (10 - NA_COUNT)` 비율로 계산합니다 — 100% `EXCELLENT`,
80% 이상이며 FAIL 없음 `GOOD`, 60% 이상이거나 FAIL 정확히 1개 `NEEDS WORK`,
60% 미만이거나 FAIL 2개 이상 `POOR`.

## 주의사항/제약

- **읽기 전용 계약.** 대상 파일을 절대 편집하지 않습니다. 수정은 사람이 하거나
  `/authoring:ux-guidelines` 가 합니다.
- **10개 전부 보고.** 첫 FAIL 에서 멈추지 않고 모든 항목에 결과를 답니다.
  환경에 도구가 없어 못 돌린 검사는 조용히 넘기지 말고 사유를 적은 N-A 로 보고합니다.
- **PASS/N-A 행에는 조치를 제안하지 않습니다.** Next Actions 는 WARN·FAIL 에만
  한 줄씩 붙고, 각 줄은 `[<LEVEL> #N]` 로 표 행과 연결됩니다.
- **표는 진단, 인용은 Next Actions.** 문제를 설명할 때는 실제 파일 라인을 인용하되
  Notes 열은 40자 이내로 유지합니다. "looks great!" 류의 군더더기 문장은 넣지 않습니다.
- **기준 참조 구현은 `shell-common/functions/git_worktree.sh`.** 어떤 패턴이
  "옳은 방식"인지 애매하면 이 파일과 비교해 판정합니다. 대상이 같은 패턴을 쓰면 PASS.
- N-A 는 파일 부류상 적용 불가일 때만 씁니다(실행 스크립트의 Interactive Guard,
  bash 전용 파일의 ZSH Compat Guard 등). 점수 분모에서 빠지므로 남용하면 Verdict 가 왜곡됩니다.
