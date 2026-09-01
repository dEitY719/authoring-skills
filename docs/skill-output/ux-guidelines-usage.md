# ux-guidelines 사용 결과

> **한 줄 요약** — raw `echo` 로만 출력하던 셸 스크립트 1개를 받아 semantic `ux_lib` 호출로 재작성된 셸 스크립트를 생성합니다.

```
lint_docs_filenames.sh  ──▶  /authoring:ux-guidelines  ──▶  lint_docs_filenames.sh
  80 lines / echo 4개          (Mode A, 파일을 씀)          122 lines / ux_* 12개
```

## 1. 실행한 명령

```
/authoring:ux-guidelines [target]
/authoring:ux-guidelines .../scratchpad/ux-demo/lint_docs_filenames.sh
```

## 2. 입력

`.../scratchpad/ux-demo/lint_docs_filenames.sh` — `~/dotfiles/scripts/lint_docs_filenames.sh` 의
폐기용 사본. 80 lines, `#!/bin/sh`, `set -eu`. `docs/` 하위 `*.md` 파일명이 kebab-case 인지 검사하고
`docs/adr`·`docs/requirement` 는 강제(exit 1), 나머지는 warn-only 로 처리한다.
리팩터링 전 raw `echo` **4개**(L23 not-found, L68 FAIL, L71 warn, L78 summary), `ux_*` **0개**.

## 3. 결과

본문 raw `echo`/`printf` **4 → 0**, `ux_*` 호출 **0 → 12**(`ux_header` `ux_info` `ux_section`
`ux_bullet` `ux_success` `ux_warning` `ux_error` 7종), 80 → **122 lines**. 파일 전체 `grep -c` 로는
`echo` 가 7개 잡히지만 전부 `ux_lib` 부재 시를 위한 폴백 스텁 정의부(L37-43)다.

구문 검사 `bash -n` OK · `zsh -n` OK · `dash -n` OK · `shellcheck -s sh` clean.
실행 동등성도 확인 — fixture 에서 `sh` 실행 시 전후 모두 errors=1/warnings=1, exit=1.

```diff
-        echo "FAIL  $file — 파일명이 kebab-case 가 아닙니다 (강제 범위)." >&2
-echo "lint-docs: errors=${errors} warnings=${warnings} (enforced: ${ENFORCED_DIRS})"
+        ux_error "FAIL  $file — 파일명이 kebab-case 가 아닙니다 (강제 범위)."
+ux_section "Summary"
+ux_bullet "errors    ${errors}"
```
`ux_error` 가 자체적으로 stderr 로 쓰므로 `>&2` 는 제거해도 라우팅이 유지된다.
