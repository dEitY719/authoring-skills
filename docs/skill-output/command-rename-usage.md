# command-rename 사용 결과

> **한 줄 요약** — 명령 패밀리와 목표 컨벤션을 받아 old→new 매핑 설계와 추적 이슈를 생성합니다.

```
scripts/*.sh + kebab-case  ──▶  /authoring:command-rename  ──▶  매핑 설계 + 추적 이슈
  (10개, 5:5 로 갈림)              (코드 수정 0건)              리스크·롤백 + refactor/docs 이슈
```

## 1. 실행한 명령

```
/authoring:command-rename <command-family> <convention> [remote]
/authoring:command-rename scripts/*.sh kebab-case origin
```

## 2. 입력

`/home/bwyoon/dotfiles/scripts/` — 최상위 `*.sh` **10개**, 네이밍이 정확히 **snake_case 5 : kebab-case 5** 로 갈려 있음.

- snake_case 5: `check_port_registry.sh` · `debug_pip_config.sh` · `lint_changelog_fragments.sh` · `lint_docs_filenames.sh` · `lint_shell_common_fallback.sh`
- kebab-case 5: `disable-git-crypt-local.sh` · `flush-transfer.sh` · `measure-skill-descriptions.sh` · `setup-skills-ssot.sh` · `verify-config-files.sh`

remote `origin` → `dEitY719/dotfiles`. 하위 `maintenance/` 의 `*.sh` 3개는 같은 디렉터리의 `*.py` 짝 이름이 깨지므로 이번 범위에서 제외.

## 3. 결과

매핑 대상은 snake_case 5건, 나머지 5건은 이미 준수라 변경 없음. 새 이름 5개 모두 충돌 0건.

| Old name | New name | 참조 지점 |
|----------|----------|-----------|
| `check_port_registry.sh` | `check-port-registry.sh` | `PORTS.md:44,51` |
| `debug_pip_config.sh` | `debug-pip-config.sh` | 외부 참조 0건 |
| `lint_changelog_fragments.sh` | `lint-changelog-fragments.sh` | `mise.toml:62`, `tests/bats/lint/changelog_fragments.bats:14`, `CLAUDE.md:109` |
| `lint_docs_filenames.sh` | `lint-docs-filenames.sh` | `mise.toml:61`, `docs/AGENTS.md:13,55` |
| `lint_shell_common_fallback.sh` | `lint-shell-common-fallback.sh` | `mise.toml:63`, `tests/bats/lint/shell_common_fallback.bats:14` |

SSOT 대조 결과 **rule gap 있음** — `scripts/` 파일명 규칙은 `command-design-pattern.md`(§1 은 함수/alias 식별자 규칙이고 적용 범위가 `shell-common/functions/*.sh`) · `command-guidelines.md` · `command-delivery-model.md` 어디에도 없습니다. 전달 방식은 불변(`symlinks.conf` 등록 0건, PATH 실행파일 아님).

**이 실행은 이슈 등록 단계(Step 6) 직전에 중단했습니다.** `gh issue create` 를 포함한 어떤 `gh` 쓰기 명령도, `Skill(gh-issue:create, ...)` 호출도 실행하지 않았으므로 **생성된 GitHub 이슈는 없고 이슈 번호도 URL 도 존재하지 않습니다**. 정상 실행이었다면 여기서 refactor 이슈 1건 + rule gap 에 따른 docs 이슈 1건이 cross-link 되어 만들어지고, `Next: /gh-flow:issue <refactor-issue-number>` 가 출력됐을 지점입니다. 대상 저장소는 읽기만 했고 `git mv` · 편집 · 커밋 전부 0건입니다.
