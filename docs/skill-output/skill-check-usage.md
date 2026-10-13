# skill-check 사용 결과

> **한 줄 요약** — `SKILL.md` 파일 하나를 받아 19개 항목의 감사 리포트를 생성합니다.

```
SKILL.md  ──▶  /authoring:skill-check  ──▶  감사 리포트 (PASS/WARN/FAIL/N-A)
```

## 1. 실행한 명령

```
/authoring:skill-check [path/to/SKILL.md | plugin:skill] [--deep-subskills]   # 일반형
/authoring:skill-check skills/sh-check/SKILL.md           # 이번 실행
```

## 2. 입력

`skills/sh-check/SKILL.md` — 이 레포의 `sh-check` 스킬 정의 파일 (88줄,
`references/` 에 checks.md · help.md · report-template.md 3개, `lib/` 에
`sh_check.sh` · `selftest.sh` 2개 보유).

## 3. 결과

Score: 17/17 checks passed (0 warnings, 0 fails, 2 N/A) · Verdict: EXCELLENT

| 판정 | 개수 | 해당 검사 |
|---|---|---|
| PASS | 17 | 1–17 |
| WARN | 0 | — |
| FAIL | 0 | — |
| N/A | 2 | 18 Plugin-root Fallback (`CLAUDE_PLUGIN_ROOT` 미사용) · 19 Credential-to-Network Flow (헬퍼가 네트워크 호출을 하지 않음) |

리포트 발췌:
```
### Security & Policy Alignment Checks
| 14 | License Declaration                | PASS | license declared in frontmatter
| 15 | Capability Declaration Consistency | PASS | no network signal in helpers
| 19 | Credential-to-Network Flow         | N/A  | no helper makes a network call
Recommended tier: haiku — audit-only linter, bounded output (declared: haiku, agrees)
```

15번은 helper(`lib/sh_check.sh`, `selftest.sh` 는 스캔 제외)에서 network signal 을 찾지
못했다 — `sh_check.sh` 의 `curl`/`wget` 탐지 정규식은 `skill_check.sh` 가 건너뛰는 `*_pattern`
대입(`call_pattern=`)에만 있다. 그래서 frontmatter 에 `compatibility.network` 선언도 필요 없다.

19번은 `checks.md` 의 N/A 기준 첫 갈래다 — 15번이 network signal 을 찾지 못했으므로 N/A.

재현: 기계 판정 8개는 `lib/skill_check.sh` 가, 나머지 11개는 감사자 판정이다.

```
sh skills/skill-check/lib/skill_check.sh skills/sh-check/SKILL.md \
  PASS PASS PASS PASS PASS PASS PASS PASS PASS PASS N/A
# 마지막 줄: score  17/17  EXCELLENT
```

Next Actions: 없음 (WARN·FAIL 0건). 대상 파일은 수정되지 않았습니다.
