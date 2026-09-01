# Model Tier → Provider ID Map

권장 티어(`haiku` / `sonnet` / `opus`)를 공급자별 실제 모델 ID 로 옮기는 매핑.
**rubric(`references/model-recommendation.md`)과 분리**하는 이유: 모델 버전은
자주 바뀌지만 티어 기준은 불변이어야 하기 때문이다 (NF-4). 버전이 바뀌면 이
파일만 갱신하고 rubric 과 전체 스킬 메타데이터는 그대로 둔다.

> 이 파일은 **advisory reference** 다. `authoring:skill-check` 는 이 매핑을 강제하지
> 않고, 런타임 모델 전환도 하지 않는다 (read-only 계약). 실제 소비는 향후
> 실행 계층(별도 후속 이슈)의 몫이다.

---

## Claude (authoritative)

아래는 **2026-05 기준 현행 Claude 4.x 패밀리의 안정적 별칭(alias) ID** 다 —
placeholder 가 아니라 실제 사용 중인 모델 식별자다. alias 는 그 패밀리의 최신
스냅샷으로 해석된다 (예: haiku 의 dated 형은 `claude-haiku-4-5-20251001`).

| Tier | Model ID (alias) | 비고 |
|---|---|---|
| `haiku` | `claude-haiku-4-5` | 경량·저비용, 정형 작업 |
| `sonnet` | `claude-sonnet-4-6` | 범용 기본 |
| `opus` | `claude-opus-4-8` | 깊은 추론·고위험 작업 |

Claude 환경에서 `tier` 는 authoritative — 실행 계층이 이 매핑으로 모델을
선택할 수 있다 (F-7). 모델 패밀리가 갱신되면 위 ID 만 교체한다 (rubric 불변).
dated/pinned ID 가 필요한 실행 계층(후속 이슈)은 alias 를 그 시점의 dated 형으로
해석하면 된다.

## Non-Claude CLI (advisory-only / skip)

codex / gemini / opencode 는 Claude 티어 개념이 없다. 강제 매핑하지 않으며,
SKILL.md 의 `metadata.model_recommendation.non_claude` 값으로 동작을 정한다:

| `non_claude` | 동작 |
|---|---|
| `advisory-only` | 리포트에 권장 티어를 정보로만 노출, 실행 영향 없음 |
| `skip` | 권장 티어 무시, 리포트에서 생략 |

아래는 참고용 느슨한 대응표일 뿐 — 공급자별 성능·명칭이 상이하므로 강제하지
않는다 (잘못된 비용·품질 결정 방지, Alternatives 거절 사유 참조).

| Tier | codex (참고) | gemini (참고) |
|---|---|---|
| `haiku` | 경량 모델 | `gemini-flash` 계열 |
| `sonnet` | 중간 모델 | `gemini-pro` 계열 |
| `opus` | 상위 추론 모델 | `gemini-pro` 상위 계열 |

## 갱신 규칙

- 모델 버전 변경 → **이 파일의 ID 만** 수정. rubric/스킬 메타데이터 불변.
- 새 티어 추가는 rubric SSOT(`model-recommendation.md`) 변경이 선행되어야 함.
- 노후화 감지: ID 가 더 이상 유효하지 않아도 tier 기준은 유지되고, 실제 ID
  매핑만 갱신한다 (Error Cases).
