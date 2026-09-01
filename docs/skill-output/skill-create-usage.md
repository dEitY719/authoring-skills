# skill-create 사용 결과

> **한 줄 요약** — 한 문장짜리 스킬 아이디어를 받아 검증을 통과한 `SKILL.md` +
> `lib/` 헬퍼 + 배포용 `.skill` 아카이브를 생성합니다.

```
스킬 아이디어 (문장)  ──▶  /authoring:skill-create  ──▶  SKILL.md + lib/ + 검증 결과 + .skill
```

## 1. 실행한 명령

```bash
/authoring:skill-create "<idea>"                                   # 일반형
/authoring:skill-create "repo의 .gitignore를 감사하는 스킬"          # 실제 실행 (비대화형, 인터뷰는 브리프로 대체)

# 스킬이 부르는 헬퍼 (cwd = skills/skill-create)
python3 scripts/quick_validate.py <scratchpad>/create-demo/gitignore-audit
python3 -m scripts.package_skill  <scratchpad>/create-demo/gitignore-audit <scratchpad>/dist
```

## 2. 입력

- 아이디어: "repo의 `.gitignore`를 감사한다 — 중복 패턴, 도달 불가능한 negation, 누락된
  공통 엔트리, 이미 tracked인 ignore 대상 파일을 읽기 전용으로 보고한다"
- 작업 디렉터리: `<scratchpad>/create-demo/` (저장소 `skills/`는 미변경)
- 픽스처: `<scratchpad>/fixture-repo` — 결함을 일부러 심은 일회용 git 저장소

## 3. 결과

생성물 3개 (`wc -l`): `SKILL.md` **71줄** · `lib/scan_gitignore.py` **103줄** ·
`evals/evals.json` **26줄**. frontmatter `name: gitignore-audit`, description 242자.

헬퍼 실물 동작(픽스처): `WARN duplicates '*.log' repeated at lines 2 and 3` /
`FAIL negation-order '!assets/keep.png' (line 5) is unreachable` /
`FAIL tracked-ignored 2 tracked file(s): .env, assets/keep.png`. 이 저장소 대상으로는 6개 전부 PASS.

검증기 출력 — `quick_validate.py`: `Skill is valid!` (exit 0) ✓
패키징 — `Successfully packaged skill to: <scratchpad>/dist/gitignore-audit.skill`,
**3,161 바이트**. 아카이브에는 `SKILL.md` 와 `lib/scan_gitignore.py` 2개만 들어감(`evals/` 제외) ✓
전체 실행 기록: `<scratchpad>/run-skill-create.txt`
