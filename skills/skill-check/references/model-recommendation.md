# Model Recommendation Metadata — rubric SSOT

Single source of truth for the **권장 모델 티어** policy (dEitY719/dotfiles#809,
supersedes dEitY719/dotfiles#807).
Shared by `authoring:skill-check` (audits/recommends, read-only) and `authoring:skill-refactor`
(generates the metadata). Keep the rubric here so the two skills never drift.

> **`authoring:skill-check` 는 read-only.** 티어를 **추천**만 하고, 모델을 직접 전환하지
> 않으며, 파일을 쓰지도 않는다. 실제 메타데이터 기입은 `authoring:skill-refactor`,
> 실제 런타임 모델 전환은 별도 후속 이슈의 몫이다.

---

## 1. Frontmatter schema

권장 티어는 기존 `metadata:` 블록 하위에 둔다 (top-level 확장보다 호환성 높음):

```yaml
metadata:
  model_recommendation:
    tier: haiku | sonnet | opus      # Claude 티어 — 안정적 티어명, 버전 ID 아님
    reason: "read-only gh metadata lookup; bounded output"
    claude: prefer                    # prefer | force  (force 는 실행계층 후속이슈 예약값)
    non_claude: advisory-only | skip  # codex/gemini/opencode degrade 동작
```

- `tier` — **필수**. `haiku` / `sonnet` / `opus` 셋 중 하나. 그 외 값은 FAIL.
- `reason` — 권장 산정 근거 한 줄. 누락 시 WARN.
- `claude` — `prefer`(권장, 기본) 또는 `force`(실행계층 후속이슈 예약값).
- `non_claude` — `advisory-only`(리포트에 노출) 또는 `skip`(무시). 강제 매핑 없음.
- `claude` / `non_claude` 를 합쳐 **compatibility** 라 부른다. 둘 다 있어야 PASS.

## 2. Tier rubric

난이도·위험도·수정 범위·추론 깊이·외부 쓰기 여부로 티어를 정한다.

| Tier | 기준 | 예시 |
|---|---|---|
| `haiku` | 읽기 전용, 짧은 요약, 정형 CLI 래핑, 낮은 추론 | `gh-issue:read`, `gh-pr:commit`, `gh-pr:create` |
| `sonnet` | 중간 난이도 분석, 리뷰 응답, 제한적 수정, CI 로그 해석 | `gh-pr:reply`, `gh-resolve:ci-fail` |
| `opus` | 깊은 구현, 대규모 리팩터링, 충돌 해결, 아키텍처 판단, 고위험 쓰기 | `gh-issue:implement`, `gh-resolve:conflict` |

원칙 (NF-1~4):
- 비용 절감 — 가벼운 스킬은 기본 `haiku`.
- 고위험 쓰기·대규모 구현·충돌 해결·깊은 설계 판단은 `opus`.
- 일반 분석·리뷰 응답·중간 난이도 수정은 `sonnet`.
- 모델명은 공급자별 버전 ID 보다 안정적 티어명을 우선 (실제 ID 는
  `references/model-tier-map.md` 로 분리).

## 3. Migration gate (WARN → FAIL)

메타데이터 누락의 결과는 **마이그레이션 단계 플래그**로 제어한다 — 43개 스킬을
day-one red wall 로 막지 않기 위함이다 (Open Question 1 결정).

- **`MIGRATION_COMPLETE = true`** (현재): 메타데이터 누락 → **FAIL**.
  전 스킬 `model_recommendation` 전수 마이그레이션 완료 (dEitY719/dotfiles#815,
  dEitY719/dotfiles#855, dEitY719/dotfiles#860, dEitY719/dotfiles#862 모두
  close) 후 별도 PR (dEitY719/dotfiles#861) 로 전환됨.
- 이전 상태 `MIGRATION_COMPLETE = false`: 누락 → **WARN** + 아래 마이그레이션
  명령 제안 (마이그레이션 유예 기간 — 종료됨).

마이그레이션 명령 (제안 문구):
`Run /authoring:skill-refactor <path> to add a metadata.model_recommendation block (rubric: references/model-recommendation.md).`

## 4. Composite skill model plan (F-5 / F-6)

합성 스킬은 본문에서 호출하는 하위 스킬을 1-depth 로 찾아 **자체 티어와
분리해** 하위 스킬별 권장 모델 계획을 표시한다.

- 탐지 패턴: 본문의 `/gh-*`, `gh:*`, `Skill(<name> ...)` 를 정규화해 후보 추출.
- 후보 스킬 파일이 있으면 그 `metadata.model_recommendation.tier` 를 읽는다.
- 파일/메타데이터가 없으면 `unknown` 으로 표시하고 WARN.
- **재귀는 기본 1-depth.** 깊은 재귀는 `--recursive` opt-in (비용·복잡도 분리,
  Open Question 2 결정).

예시 — `gh-flow:issue` 는 자체 티어(오케스트레이션 → `sonnet`)와 5개 하위
스킬 계획을 따로 리포트한다 (`Sub-skill Model Plan` 섹션, report-template.md).

## 5. Compatibility policy (F-7 / F-8)

- **Claude**: `tier` 를 실행 계층(후속 이슈)이 소비할 authoritative metadata 로
  취급한다. 단 `authoring:skill-check`/`authoring:skill-refactor` 자체는 모델을 전환하지 않는다.
- **codex / gemini / opencode**: 실행 모델 전환 기능이 없으면 `tier` 를
  `non_claude` 값에 따라 advisory metadata 로 리포트(`advisory-only`)하거나
  무시(`skip`)한다. Claude 모델명을 강제 매핑하지 않는다.
- 공급자별 실제 모델 ID 는 `references/model-tier-map.md` 로 분리해 모델 버전
  변경 시 이 rubric 은 불변으로 유지한다.

## 6. `authoring:skill-refactor` 연동 (F-9)

`authoring:skill-refactor` 는 이 SSOT 를 읽어 누락된 스킬 frontmatter 에
`metadata.model_recommendation` 블록을 **생성**한다 (보존이 아니라 생성,
Open Question 3 결정). 추천 로직(Section 2 rubric)을 양쪽이 공유하므로 중복
판단을 막는다. 전체 마이그레이션은 이 이슈 구현 후 별도로 수행한다.
