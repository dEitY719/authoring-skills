# skill-check

## 한 줄 요약

`SKILL.md` 파일 하나(또는 레포 하나, 디렉터리 아래 모든 레포의 스킬 전부)를 19개 기준으로 감사해 **감사 리포트(문서)** 를 만들어 낸다.
대상 파일을 고치지 않는다 — 산출물은 수정된 스킬이 아니라 PASS / WARN / FAIL / N/A
판정표와 Score, Verdict, Next Actions 로 이루어진 리포트 한 벌이다.

## 언제 쓰고 언제 안 쓰는가

| 상황 | 쓸 스킬 | 이유 |
|---|---|---|
| `SKILL.md` 품질을 점검만 하고 싶다 | **`skill-check`** | read-only 감사, 리포트만 생성 |
| 점검 결과 100줄 초과·구조 문제를 실제로 고쳐야 한다 | `skill-refactor` | 이쪽이 `references/` 로 내용을 빼내며 파일을 **쓴다** |
| 대상이 `*.sh` 셸 스크립트다 | `sh-check` | 10개 기준의 셸 전용 감사 |
| 대상이 `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` 다 | `harness:ai-context` | frontmatter 의 negative trigger 가 명시 |
| 새 스킬을 처음부터 만든다 | `skill-create` | 그 절차의 10번째 단계에서 `skill-check` 를 품질 게이트로 호출한다 |

경계 요약:

- `skill-check` 는 **감사만**, `skill-refactor` 는 같은 문제를 **다시 쓴다**.
  `skill-refactor` 는 작업을 마치면 `Next: /authoring:skill-check <path>` 로 되돌려 보낸다.
- `skill-create` 는 새 스킬을 저술하고, 마지막에 `/authoring:skill-check` 를 돌려
  FAIL/WARN 이 나오면 곧바로 `/authoring:skill-refactor` 를 부른다.
- `sh-check` 는 이 스킬의 셸 스크립트판 거울(mirror)이다. 대상 확장자로 갈린다.

## 호출 형식과 인자/옵션

```
/authoring:skill-check [path/to/SKILL.md | plugin:skill] [--issue] [--deep-subskills]
/authoring:skill-check -d <dir> | -r <git-url> | -R <root> [--no-issue] [-y]
```

`references/help.md` 가 인자/옵션의 SSOT 다.

| 인자/옵션 | 설명 | 기본값 |
|---|---|---|
| `[path \| skill-name]` | 감사할 `SKILL.md`, 스킬 디렉터리, 또는 `plugin:skill` / `skill` | 생략 시 현재 디렉터리부터 `SKILL.md` 탐색 |
| `-d, --dir <dir>` | 디렉터리(레포) 아래 모든 스킬 | — |
| `-r, --repo <git-url>` | URL 을 임시로 shallow clone 해서 모든 스킬 감사 | — |
| `-R, --recursive <root>` | `<root>` 직속 하위의 모든 git 레포 | — |
| `--issue` | 단일 모드에서 이슈 등록 opt-in | off |
| `--no-issue` | 일괄 모드에서 이슈 등록 끄기 (작업 트리 감사, read-only) | 일괄 모드는 on |
| `-y, --yes` | Issue Plan 확인 생략 (무인 실행) | off |
| `--deep-subskills` | 합성 스킬(composite)의 Sub-skill Model Plan 을 기본 1-depth 보다 깊게 순회 (이전 `--recursive`) | off |
| `help` | 이 도움말을 그대로 출력하고 중단. 검사 미실행 | — |

예시:

```
/authoring:skill-check
/authoring:skill-check skills/my-skill/SKILL.md
/authoring:skill-check gh-flow:wave
/authoring:skill-check skills/my-composite-skill/SKILL.md --deep-subskills
/authoring:skill-check -d ~/src/my-skills/ --no-issue
/authoring:skill-check -R ~/src/
/authoring:skill-check help
```

## 동작 단계 요약

SKILL.md 가 정의한 실제 흐름은 Help 분기 + 5단계다.

1. **Help** — 인자가 `help` 이면 `references/help.md` 를 그대로 출력하고 종료.
2. **Step 0: Parse Arguments** — `lib/skill_scan.sh args` 가 모드(single/dir/repo/recursive)와
   이슈 등록 여부를 정한다. 인자 오류와 이전 형식 `<path> --recursive` 는 exit 2.
3. **Step 1: Locate the Files** — 단일 모드는 경로나 스킬 이름(`skill_scan.sh resolve`),
   일괄 모드는 `skill_scan.sh scan` 이 감사 목록을 만든다(`references/batch-mode.md`).
4. **Step 2: Run Nineteen Checks** — `references/checks.md` 의 19개 정의를 읽고
   검사마다 PASS/WARN/FAIL/N/A 를 하나씩 배정한다.
5. **Step 3: Output the Report** — `references/report-template.md` 의 형식 그대로 출력.
   일괄 모드는 Batch Summary 와 Issue Plan 표를 낸다.
6. **Step 4: File Issues** — 일괄 모드(또는 단일 `--issue`)에서만. `references/issue-filing.md`.

19개 검사 그룹:

| 그룹 | 번호 | 항목 |
|---|---|---|
| Structure | 1–5 | Line Count · Progressive Disclosure · Frontmatter Validity · References Directory · Output Report |
| UX Quality | 6–12 | Help Flag Pattern · Step Structure · Options Documentation · Verdict Output · Next-action Hint · No Emojis · Executable Procedure Extraction |
| Model | 13 | Model Recommendation Metadata (`metadata.model_recommendation` tier/reason/compatibility) |
| Security & Policy | 14–15, 19 | License Declaration · Capability Declaration Consistency · Credential-to-Network Flow (19, 모델 판정, WARN 전용) |
| Context Budget | 16 | Description Length |
| Portability | 17–18 | Bundle Self-containment · Plugin-root Fallback (WARN 전용 — 다른 하네스가 스킬 디렉터리 하나만 설치해도 실행되는가) |

보조 참조 파일: 티어 판정 기준은 `references/model-recommendation.md`(rubric SSOT),
공급자별 모델 ID 는 `references/model-tier-map.md`, `name:` 표기 판정은
`references/naming-convention.md`, Check 11 의 예외 목록은
`references/allowed-emoji-skills.txt` 가 각각 SSOT 다.

## 주의사항 / 제약

- **파일을 쓰지 않는다 — 외부 쓰기는 일괄 이슈 등록 하나뿐.** 티어를 추천만 하고 모델을
  전환하지 않으며, 감사 대상 파일을 고치지 않는다. Check 13·14·15·19 모두 정책 격차를
  지적할 뿐이고, 실제 기입은 `skill-refactor` 의 몫이다. 유일한 외부 쓰기는 일괄 모드
  (`-d`/`-r`/`-R`, 또는 단일 `--issue`)의 이슈 등록이며, Issue Plan 을 보여 주고 확인을
  한 번 받은 뒤에만 한다(`-y` 는 생략, `--no-issue` 는 끔). 단일 모드 기본 실행과
  `skill-create`/`skill-refactor` 가 부르는 경로는 이슈를 만들지 않는다. `git push` 는 하지 않는다.
- **이슈는 upstream 우선, 스냅샷 기준.** 대상은 `upstream` remote, 없으면 `origin` 이다.
  이슈를 등록하는 실행은 로컬 작업 트리가 아니라 대상 레포 기본 브랜치의 스냅샷을 감사하므로,
  feature 브랜치나 dirty 상태의 로컬 전용 내용이 이슈 본문에 들어가지 않는다. 스킬 1개당
  이슈 1건이고, 본문 마지막 줄 `skill-check-key: <plugin>:<skill>` 로 열린 이슈를 찾아 중복을 막는다.
- **첫 실패에서 멈추지 않는다.** 19개 전부를 판정해 전체 리포트를 낸다.
- **Score 분모에서 N/A 는 제외**한다(19 − N/A 개수). Verdict 는 전원 PASS →
  `EXCELLENT`, 80% 이상이며 FAIL 없음 → `GOOD`, 60% 이상이거나 FAIL 존재 →
  `NEEDS WORK`, 60% 미만 → `POOR`.
- **Issues & Improvements 에는 WARN 과 FAIL 만** 싣고, 문제를 설명할 때는 대상 파일의
  실제 줄을 인용한다.
- **Check 16 은 바이트가 아니라 문자 수**로 센다(한글 1글자 = 3바이트라 바이트로 세면
  약 3배 과대 보고). PASS ≤ 250 · WARN 251–400(정당화 주석 필요) · FAIL > 400.
  description 은 매 세션 `available_skills` 목록에 적재되고 Codex/Kimi 는 설치된 전체
  스킬 합계를 약 5,440자로 제한하므로, 이 예산이 검사 근거다.
- **Check 16 은 길이만 잰다.** 트리거 정확도는 read-only 감사 범위 밖이며
  `references/trigger-eval-procedure.md` 의 수동 하네스가 담당한다.
- **Sub-skill Model Plan 섹션은 합성 스킬에만** 나온다. 본문이 다른 스킬을 호출하지
  않는 leaf 스킬이면 통째로 생략한다.
- **마켓플레이스 레포에서는 `name:` 이 bare 형**(`skill-check`)이어야 하고 콜론은 CI
  실패다. 개인 스킬 트리(`~/dotfiles/claude/skills/`)에서만 `category:action` 콜론
  형태가 PASS 다 — 판정 전에 대상이 어느 세계에 있는지 먼저 가린다.
