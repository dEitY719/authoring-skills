# skill-refactor 사용 결과

> **한 줄 요약** — 100줄을 넘긴 `SKILL.md` 한 개를 받아 100줄 이하로 다시 쓴
> `SKILL.md`와 상세 내용을 옮겨 담은 `references/` 트리를 생성합니다.

```
884줄 SKILL.md  ──▶  /authoring:skill-refactor  ──▶  92줄 SKILL.md + references/ 8개
```

## 1. 실행한 명령

```bash
/authoring:skill-refactor [path/to/SKILL.md]        # 일반형
/authoring:skill-refactor <scratchpad>/refactor-demo/SKILL.md   # 실제 실행
```

## 2. 입력

- 경로: `<scratchpad>/refactor-demo/SKILL.md` (원본 미변경, 일회용 사본)
- 내용: `plugin-dev` 플러그인의 `command-development` SKILL.md
- 원본 라인 수: **884줄** — 100줄 한도의 8.8배. 기존 `references/` 없음

## 3. 결과

`SKILL.md` **884줄 → 92줄** (89.6% 감소), `references/` **0개 → 8개**.

| 생성된 참조 파일 | 줄 수 |
|---|---|
| `references/plugin-commands.md` | 241 |
| `references/arguments-and-references.md` | 146 |
| `references/organization-and-best-practices.md` | 109 |
| `references/command-basics.md` | 103 |
| `references/common-patterns.md` | 101 |
| `references/frontmatter-fields.md` | 88 |
| `references/validation-patterns.md` | 82 |
| `references/help.md` | 22 (신규 — 원본에 도움말 없음) |

검증: 92줄 ✓ / frontmatter 무변경 ✓ / 참조 8개 모두 `SKILL.md`에서 트리거 ✓ /
각 참조 300줄 이하(최대 241) ✓ → `[OK] refactor complete`
`lines_before=884 lines_after=92 files_created=8`
