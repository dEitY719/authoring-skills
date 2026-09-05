# skill-create

## 한 줄 요약

한 문장짜리 아이디어를 받아, **검증을 통과하고 패키징까지 끝난 스킬 디렉터리**
(`SKILL.md` + 필요하면 `lib/` `references/` `evals/`, 그리고 배포용 `<name>.skill`)를
산출한다. 인터뷰 → 초안 → eval 루프 → description 튜닝 → 패키징 → 품질 게이트가
한 흐름으로 이어지는 저작(authoring) 스킬이다.

핵심 설계는 **executable-first gate**다. 결정적이고 반복적인 절차 — 파일 생성/변환,
반복 CLI 호출, 다단계 폴백, 파싱·검증·집계 — 는 산문이 아니라 `lib/`로 내려가고,
산문에는 판단과 근거, 결과 해석, 사용자 커뮤니케이션만 남는다.

## 언제 쓰고 언제 안 쓰는가

**쓸 때**

- 없는 스킬을 처음부터 만들 때. 이 저장소의 세 저작 스킬 중 유일하게 **새로 만드는**
  쪽이다.
- 이미 있는 스킬을 고치거나 최적화할 때. description이 그렇게 말한다 —
  "Create a skill, or improve and evaluate an existing one."
- 스킬이 제대로 트리거되지 않을 때. Phase 6의 description 최적화 루프가
  should-trigger / should-not-trigger 쿼리로 실측해 문구를 다시 뽑는다.
- 두 버전 중 어느 쪽이 나은지 수치로 알고 싶을 때(eval + benchmark).

**쓰지 않을 때**

- **점검만 하고 싶을 때** → `/authoring:skill-check`. 16개 항목 감사이고 **읽기 전용**이다.
- **100줄을 넘긴 `SKILL.md`를 줄이고 싶을 때** → `/authoring:skill-refactor`.
  기존 파일을 `references/`로 쪼개는 전용 도구다. 다만 이 스킬의 Phase 8은 그
  리팩터링을 스스로 호출한다.
- **셸 스크립트 감사**는 `/authoring:sh-check`, AI 컨텍스트 문서(`CLAUDE.md` /
  `AGENTS.md` / `GEMINI.md`)는 애초에 대상이 아니다.

## 호출 형식과 인자/옵션

```
/authoring:skill-create                # 대화형 — 의도 파악부터 시작
/authoring:skill-create "<idea>"       # 짧은 아이디어/주제로 시드
/authoring:skill-create -h|--help|help # references/help.md 출력 후 중단
```

슬래시 인자는 위가 전부다. 실제 옵션은 각 단계에서 부르는 헬퍼 스크립트에 있고,
모두 `skills/skill-create/` 디렉터리에서 실행한다.

| 스크립트 | 호출 형태 / 주요 인자 |
|---|---|
| `scripts/quick_validate.py` | `python quick_validate.py <skill_dir>` — 인자 1개 고정. frontmatter 검증, 유효하면 exit 0 |
| `scripts/package_skill.py` | `python -m scripts.package_skill <skill_dir> [output_dir]` — 위치 인자만, 검증 후 zip |
| `scripts/run_eval.py` | `--eval-set --skill-path` (필수), `--description --num-workers(10) --timeout(30) --runs-per-query(3) --trigger-threshold(0.5) --model --verbose` |
| `scripts/run_loop.py` | `--eval-set --skill-path --model` (필수), `--max-iterations(5) --runs-per-query --timeout --num-workers --trigger-threshold --verbose` |
| `scripts/improve_description.py` | `--eval-results --skill-path --model` (필수), `--history --verbose` |
| `scripts/generate_report.py` | `<input.json>` 위치 인자(`-`는 stdin), `-o/--output --skill-name` |
| `scripts/aggregate_benchmark.py` | `<benchmark_dir>` 위치 인자, `--skill-name --skill-path` |
| `eval-viewer/generate_review.py` | `<workspace>` 위치 인자, `-p/--port(3117) -n/--skill-name`, `--benchmark --previous-workspace --static` |

`agents/{grader,comparator,analyzer}.md`는 스크립트가 아니라 서브에이전트 프롬프트다 —
각각 assertion 채점, 블라인드 A/B 비교, 승자 분석을 맡는다.

## 동작 단계 요약

**Phase 1 — 의도 포착.** 무엇을 가능하게 하는가 / 언제 트리거되는가 / 출력 형식은
무엇인가 / 테스트 케이스를 둘 것인가, 네 가지를 묻는다. "이 대화를 스킬로 만들어줘"면
대화 기록에서 먼저 답을 뽑는다.

**Phase 2 — 인터뷰와 조사.** 엣지 케이스, 입출력 형식, 성공 기준, 의존성을 파고든다.
초안 전에 **헬퍼 후보를 분류**한다 — 이게 executable-first gate다.

**Phase 3 — SKILL.md 작성.** `references/skill-writing-guide.md`가 해부도, progressive
disclosure, frontmatter 필드, description 예산(250자 이하), 테스트 케이스 형식을 담는다.

**Phase 4 — 실행과 평가.** `references/eval-pipeline.md`의 파이프라인: 케이스마다
with-skill / baseline 두 서브에이전트를 **같은 턴에** 띄우고, 도는 동안 assertion을
쓰고, 완료 알림의 `total_tokens`/`duration_ms`를 즉시 `timing.json`에 남긴다(이때가
유일한 기회다). 채점 → `aggregate_benchmark` → 애널리스트 패스 → 뷰어 순이며,
뷰어는 **직접 평가하기 전에** 띄운다.

**Phase 5 — 개선.** `references/improvement-philosophy.md`. 몇 개 예제에 과적합하지 말
것, 프롬프트를 군살 없이 유지할 것, 대문자 MUST 대신 **이유를 설명할 것**, 그리고 여러
테스트가 똑같은 헬퍼를 각자 짜고 있으면 그건 `lib/`로 올리라는 신호다.

**Phase 6 — description 최적화.** should-trigger 8~10개 + near-miss 8~10개로 20개
쿼리를 만들어 `assets/eval_review.html`로 사용자 검토를 받고, `run_loop`로 train 60% /
held-out test 40% 분할 루프를 돌려 test 점수 기준 `best_description`을 고른다.

**Phase 7 — 패키징.** `python -m scripts.package_skill <path>`로 `.skill` 파일을 만들고
경로를 알려준다(루트 `evals/`는 아카이브에서 제외된다).

**Phase 8 — 품질 게이트.** 새 `SKILL.md`에 `/authoring:skill-check`를 돌리고, FAIL이나
WARN이 하나라도 있으면 즉시 `/authoring:skill-refactor`로 100줄 아래로 내린 뒤
before/after 라인 수를 보고한다.

## 주의사항/제약

- **이 스킬은 파일을 쓴다.** 새 디렉터리, `SKILL.md`, `lib/`, `evals/`, `.skill`
  아카이브를 만든다. 읽기 전용인 `skill-check` / `sh-check`와 안전 계약이 다르다.
- **Python이 필요하다.** 헬퍼는 설명용 의사코드가 아니라 실제 진입점이며,
  `quick_validate.py`는 `pyyaml`을, `package_skill.py`는 `scripts.` 패키지 임포트를 써서
  스킬 디렉터리에서 `python -m scripts.package_skill` 형태로 돌려야 한다.
- **헬퍼를 고쳐라, 산문으로 우회하지 말고.** 이 저장소의 규칙이자 이 스킬이 스스로
  가르치는 규칙이다. 절차가 결정적이면 `lib/`로 내린다.
- **막히면 멈추고 보고한다.** `package_skill`이 실패했는데 조용히 다음 단계로
  넘어가지 않는다.
- **description은 250자 이하로.** 설치된 모든 스킬의 description이 세션 목록에 함께
  실리고 Codex/Kimi는 그 합계를 약 5,440자로 자른다 — 긴 description은 남의 자리를
  뺏는다.
- `references/local-patches.md`가 이 사본의 로컬 패치 이력(dEitY719/dotfiles#1412 등)을 기록한다 —
  마켓플레이스 원본에서 재임포트하는 흐름은 없고, 이 사본이 SSOT다.
- 플랫폼 제약은 `references/platform-instructions.md`: Claude.ai에는 서브에이전트가
  없어 baseline 실행과 description 최적화(`claude -p` 필요)를 건너뛴다.
