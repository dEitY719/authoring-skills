# skill-refactor

## 한 줄 요약

100줄을 넘긴 `SKILL.md` 하나를 받아, **100줄 이하로 다시 쓴 `SKILL.md` + 새로 만든
`references/` 트리**를 산출한다. 내용을 버리는 것이 아니라 옮긴다 — 워크플로(단계와
판단 로직)만 `SKILL.md`에 남기고, 템플릿·예시·도메인 지식·긴 체크리스트는
`references/*.md`로 빼낸 뒤 그 자리에 "언제 읽어라" 포인터 한 줄을 넣는다.

Progressive Disclosure의 원칙은 `SKILL.md`가 **관제탑**(단계와 포인터만),
`references/`가 **지식 베이스**(템플릿·예시·상세)라는 것이다. 사용자가 `SKILL.md`만
읽고 2분 안에 전체 워크플로를 이해할 수 있으면 성공이다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때**

- `SKILL.md`가 100줄을 넘어 CI 라인 수 게이트에 걸릴 때.
- `/authoring:skill-check`가 길이/구조 항목에서 FAIL 또는 WARN을 냈을 때. 감사는
  `skill-check`가 하고, **고쳐 쓰는 것은 이 스킬이다.** 순서는 항상 감사 먼저,
  리팩터링 나중.
- 스킬 본문에 출력 템플릿, 대형 참조 표, 15줄 넘는 예시가 인라인으로 박혀 있어
  단계 흐름이 묻힐 때.

**쓰지 않을 때**

- **새 스킬을 처음부터 만들 때** → `/authoring:skill-create`. 이 스킬은 이미 있는
  파일을 다시 쓰는 도구이지, 없는 스킬을 만들어내지 않는다.
- **점검만 하고 싶을 때** → `/authoring:skill-check` (읽기 전용, 16개 항목 감사).
- **`AGENTS.md` / `CLAUDE.md` / `GEMINI.md`** 같은 AI 컨텍스트 문서. 대상이 아니다.
  `SKILL.md` 전용이다. 셸 스크립트는 `/authoring:sh-check`.
- 이미 100줄 이하이고 구조가 멀쩡한 스킬. 이 경우 Step 1에서 "통과"를 알리고
  아무것도 쓰지 않은 채 멈춘다.

## 호출 형식과 인자/옵션

```
/authoring:skill-refactor [path/to/SKILL.md]
```

| 인자 | 의미 |
|---|---|
| `[path]` | 리팩터링할 `SKILL.md` 경로. **생략 가능** — 생략하면 현재 디렉터리부터 `SKILL.md`를 찾는다. |
| `-h`, `--help`, `help` | `references/help.md`를 그대로 출력하고 중단. 파일을 읽지도 쓰지도 않는다. |

플래그는 이게 전부다. `--dry-run`이나 `--apply` 같은 옵션은 없다 — 애초에 쓰기 전에
계획을 제시하고 멈추는 것이 기본 동작이기 때문이다.

## 동작 단계 요약

**Step 1 — 분석.** 대상 `SKILL.md`를 통째로 읽고 라인 수를 센다. 이미 100줄 이하이고
구조가 좋으면 여기서 통과 처리하고 끝낸다. 아니면 추출 대상(출력 템플릿, 참조 표,
설정 예시, 도메인 지식, 긴 체크리스트, 15줄 초과 예시)과 남길 대상(단계, 순서, 판단
로직)을 분류하고, `references/` 디렉터리가 이미 있는지 확인한다.

**Step 2 — 리팩터링 계획 수립.** `references/plan-and-report-templates.md`의 계획
템플릿에 맞춰, "어느 섹션 → 어느 `references/` 파일 → 언제 로드되는가"를 표로 제시한다.
**여기서 멈추고 사용자 확인을 기다린다.**

**Step 3 — 실행.** 확인을 받은 뒤에야 쓴다.

- `references/` 파일 생성: 파일당 단일 책임, 헤더는 `# <주제> — <목적>`, 각 300줄 이하.
- `SKILL.md` 재작성: frontmatter는 그대로 두고(문제가 있을 때만 수정), 빼낸 블록 자리에
  `Read references/<file>.md when <조건>.` 포인터를 넣고, 단계 설명은 행동 지향
  한 줄로 압축한다.
- `references/help.md`가 없는 스킬이면 이때 만든다 — 도움말은 항상 도달 가능해야 한다.
- 검증: 100줄 이하인가, 모든 `references/` 파일이 `SKILL.md`에서 트리거되는가,
  출력 형식이 여전히 도달 가능한가.

**Step 4 — 보고.** 완료 리포트 템플릿으로 before/after 라인 수, 생성된 참조 파일 목록,
검증 표를 낸다. 마지막 줄은 `[OK] refactor complete` 또는 `[FAIL] <이유>`와
`lines_before= lines_after= files_created=` 요약, 그리고 다음 단계 안내
`Next: /authoring:skill-check <path>`로 끝난다.

## 주의사항/제약

- **이 스킬은 파일을 쓴다.** `skill-check` / `sh-check`와 달리 읽기 전용이 아니다.
  기존 `SKILL.md`를 통째로 덮어쓰고 새 `references/` 파일들을 만든다.
- **쓰기 전에 반드시 계획을 제시하고 확인을 기다린다.** 이것이 이 스킬의 안전 계약이다.
  확인 없이 Step 3으로 넘어가면 계약 위반이다.
- **먼저 백업하거나 버전 관리 아래에서 실행하라.** 커밋되지 않은 `SKILL.md`를 대상으로
  돌리면 되돌릴 방법이 없다. 실행 전 `git status`가 깨끗한 것이 가장 안전하다.
- **frontmatter의 `name:`을 마음대로 바꾸지 않는다.** 특히 `name: foo:bar` 콜론 형식을
  VS Code 진단을 이유로 `foo-bar`로 조용히 고치는 것은 금지다. 대상 스킬이 콜론 형식을
  쓰면 `references/naming-convention.md`를 읽고 바이트 단위로 보존한다. 다만
  마켓플레이스 레포(루트에 `.claude-plugin/plugin.json`이 있는 저장소)에서는 bare
  이름이 맞고 콜론은 CI 실패다 — 어느 쪽 세계인지 먼저 판단할 것.
- **추출은 이동이지 요약이 아니다.** 빼낸 내용을 임의로 줄이면 정보가 사라진다.
  `SKILL.md` 쪽 단계 설명만 압축한다.
- 리팩터링 후에는 `/authoring:skill-check <path>`로 결과를 검증하는 것으로 마무리한다.
