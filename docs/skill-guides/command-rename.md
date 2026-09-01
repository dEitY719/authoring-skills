# command-rename

## 한 줄 요약

명령 패밀리 하나와 목표 네이밍 컨벤션을 받아, old→new 매핑 표 · 동작 보존 근거 ·
리스크/롤백 계획으로 이뤄진 **리네임 설계**를 만들고 그것을 담은 **GitHub 추적
이슈**를 등록합니다. 코드는 한 줄도 바꾸지 않습니다 — 실제 리네임은 나중에
`/gh:issue-flow <refactor-issue-number>` 가 수행합니다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때**

- alias/함수/스크립트 이름이 컨벤션 없이 갈려 있고, 그걸 한 번에 정리하고 싶을 때
- 리네임의 **blast radius**(정의 지점 + 모든 참조 지점)를 먼저 파악하고 싶을 때
- 정리 작업을 지금 하지는 않되 추적 이슈로 남겨 순번에 넣고 싶을 때

**쓰지 않을 때** — 이 스킬의 경계는 "설계와 등록까지"입니다.

| 하고 싶은 일 | 담당 | 비고 |
|--------------|------|------|
| 실제로 파일/심볼을 리네임하고 커밋·PR 까지 | `/gh:issue-flow <N>` | command-rename 이 만든 refactor 이슈 번호를 넘긴다 |
| `*.sh` 품질 감사 | `/authoring:sh-check` | 읽기 전용 감사. 리네임 설계와 무관 |
| `SKILL.md` 감사 | `/authoring:skill-check` | 마찬가지로 감사 전용 |
| help 텍스트를 `ux_lib` 호출로 치환 | `/authoring:ux-guidelines` | 실제 코드를 고치는 쪽 |

즉 command-rename 은 **코드 리팩터러가 아니고**, `sh-check`/`skill-check` 같은
**감사기도 아닙니다**. 설계 → 이슈 등록에서 멈추고, 그 이슈를 실행하는 것은
별도의 `/gh:issue-flow` 실행입니다. SKILL.md 의 Role 절과
`references/constraints.md` 첫 항목이 이 계약을 명시합니다.

## 호출 형식과 인자/옵션

```
/authoring:command-rename <command-family> <desired-convention> [remote]
/authoring:command-rename -h
```

`references/help.md` 가 인자 표면의 SSOT 입니다.

| # | 인자 | 기본값 | 의미 |
|---|------|--------|------|
| 1 | `<command-family>` | — | 리네임 대상 명령/alias 패밀리(예: `agy`). **필수**. 모호하면 후보를 보여주고 되묻습니다 — 추측하지 않습니다 |
| 2 | `<desired-convention>` | — | 목표 컨벤션(예: `dash-form`, `snake_case`, `<tool>-<noun>`). **필수** |
| 3 | `[remote]` | `origin` | 새 이슈를 소유할 git remote **이름**. 없는 remote 면 `git remote -v` 를 출력하고 즉시 실패 |
| — | `-h`, `--help`, `help` | — | `references/help.md` 를 그대로 출력하고 **중단**. API 호출 없음 |

종료 코드는 `0` 이슈 생성 완료, `1` 사전조건 실패(git repo 아님 / remote 없음 /
`gh auth` 실패 / `gh:issue-create` 실패), `2` 필수 인자 누락입니다.

## 동작 단계 요약

1. **입력 파싱 + 저장소 해석** (`references/repo-resolution.md`) —
   `git rev-parse --show-toplevel` 로 repo 확인, remote URL 에서 `owner/repo` 를
   뽑아 `TARGET_REPO` 로 보관. 지정한 remote 가 없으면 **`origin` 으로 조용히
   폴백하지 않고** 그 자리에서 멈춥니다(오타를 감춰 엉뚱한 repo 에 이슈를
   올리는 사고 방지).
2. **발견(discovery)** (`references/discovery.md`) — 정의 지점
   (`shell-common/tools/integrations/*.sh`, `shell-common/functions/*.sh`)과
   참조 지점 **전 카테고리**를 훑습니다: inline help/DOC 블록, `install_*.sh`,
   `my_help.sh` 의 `HELP_DESCRIPTIONS` 등록, `zz_help_standard_adapter.sh`,
   `tests/integration/test_help_*.py`, `tests/bats/**`. 한 카테고리를 빠뜨리면
   리네임 후 dangling reference 가 남습니다. 여기서 모은 file:line 목록이
   이슈의 "범위(Scope)" 가 됩니다.
3. **SSOT 대조 + 규칙 공백 탐지** (`references/ssot-check.md`) —
   `docs/.ssot/command-design-pattern.md`(§1 명명 규칙표, §8 deprecated shim),
   `command-guidelines.md`(help UX), `command-delivery-model.md`(함수 vs PATH
   실행파일) 세 문서를 전부 읽고 경로로 인용합니다. 요청한 컨벤션이 기존 SSOT
   섹션에 **문자 그대로** 없으면 그것이 **rule gap** 입니다.
4. **git 계열 축약 제외** — `gb`, `gwt` 같은 고빈도 git 관용 축약은 요청한
   컨벤션과 무관하게 항상 후보에서 뺍니다. 근육 기억을 깨는 대가가 네이밍
   일관성 이득보다 큽니다. 제외 사실은 이슈 본문에 명시합니다.
5. **매핑 설계(대화형)** (`references/mapping-design.md`) — old→new 표를 만든 뒤
   **두 가지는 반드시 사용자에게 묻습니다**: 이름별 하위 호환 정책(§8 deprecated
   shim vs hard removal)과 이름 충돌 해소 방법. 자동 결정 금지. 의도적으로
   삭제되는 이름은 "Removed / dropped" 절에 따로 나열합니다.
6. **이슈 생성** (`references/issue-creation.md`) — `Skill(gh:issue-create, ...)`
   에 "refactor" 의도를 명시해 refactor 템플릿(TL;DR / 동기 / 범위 / Before-After /
   동작보존 / 리스크·롤백 / 검증 / References)이 잡히게 합니다. 3단계에서 rule gap
   을 찾았을 **때만** `docs` 이슈를 하나 더 만들고 `gh issue comment` 로 양방향
   cross-link 합니다. `gh issue create` 직접 호출은 금지입니다.
7. **리포트** (`references/report-template.md`) — 생성된 이슈 번호 + URL,
   `[OK]`/`[FAIL]` 판정, 그리고 `Next: /gh:issue-flow <refactor-issue-number>` 힌트.

## 주의사항/제약

- **바깥으로 나가는 부작용이 있습니다.** 이 스킬은 실제 GitHub 이슈를 만듭니다 —
  6개 스킬 중 유일하게 저장소 밖에 흔적을 남깁니다. `gh` 인증이 필요하고, 실행
  전에 대상 remote 가 맞는지 확인하세요. 인증 실패는 종료 코드 1 입니다.
- **소스는 절대 건드리지 않습니다.** 편집도 커밋도 없고, 모든 탐색은
  `grep`/`Read` 읽기 전용입니다. 리네임은 `/gh:issue-flow` 의 몫입니다.
- **SSOT 문구를 지어내지 않습니다.** 컨벤션이 SSOT 에 없으면 rule gap 으로
  보고하고 `docs` 이슈를 만들 뿐, SSOT 문서에 제안 규칙을 써넣지 않습니다.
  실제 문구는 그 docs 이슈에서 나중에 설계합니다.
- **`docs` 이슈는 gap 이 있을 때만.** 공백이 없으면 refactor 이슈 하나로 끝이고
  cross-link 도 없습니다.
- **전달 방식 축을 넘지 않습니다.** 매핑이 명령을 셸 함수 ↔ PATH 실행파일 사이로
  옮기면 안 됩니다(`command-delivery-model.md`). 리네임은 이름 축에만 머물고,
  이슈에는 "delivery model unchanged" 를 적습니다.
- **동작 보존이 전제입니다.** 리네임은 무엇이라 불리는지만 바꾸고 무엇을 하는지는
  바꾸지 않습니다. 이슈의 동작보존 절이 그 사실을 진술해야 합니다.
- **하위 호환·충돌 결정은 자동화 대상이 아닙니다.** 이 두 질문에 답을 받기 전에는
  이슈를 만들지 않습니다.
