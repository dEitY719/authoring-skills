# skill-check 사용 결과

> **한 줄 요약** — `SKILL.md` 파일 하나를 받아 16개 항목의 감사 리포트를 생성합니다.

```
SKILL.md  ──▶  /authoring:skill-check  ──▶  감사 리포트 (PASS/WARN/FAIL/N-A)
```

## 1. 실행한 명령

```
/authoring:skill-check [path/to/SKILL.md] [--recursive]   # 일반형
/authoring:skill-check skills/sh-check/SKILL.md           # 이번 실행
```

## 2. 입력

`skills/sh-check/SKILL.md` — 이 레포의 `sh-check` 스킬 정의 파일 (99줄,
`references/` 에 checks.md · help.md · report-template.md 3개 보유).

## 3. 결과

Score: 11/15 checks passed (4 warnings, 0 fails, 1 N/A) · Verdict: NEEDS WORK

| 판정 | 개수 | 해당 검사 |
|---|---|---|
| PASS | 11 | 1–7, 9–11, 13 |
| WARN | 4 | 8 Options Documentation · 12 Executable Procedure Extraction · 14 License Declaration · 16 Description Length |
| FAIL | 0 | — |
| N/A | 1 | 15 Capability Declaration Consistency (실행 헬퍼 없음) |

리포트 발췌:
```
| 1  | Line Count            | PASS | 99 lines — within 100-line goal
| 14 | License Declaration   | WARN | no frontmatter license; repo LICENSE = MIT
| 16 | Description Length    | WARN | 260 chars (251-400) — no justifying comment
Recommended tier: haiku (declared: haiku, agrees)
```

Next Actions 1순위: frontmatter 에 `license: MIT` 추가. 대상 파일은 수정되지 않았습니다.
