# sh-check 사용 결과

> **한 줄 요약** — 셸 스크립트 파일 1개를 받아 10개 기준 PASS/WARN/FAIL/N-A 감사 리포트를 생성합니다.

```
check_port_registry.sh  ──▶  /authoring:sh-check  ──▶  10개 기준 감사 리포트
   (118 lines)                  (read-only)            표 2개 + Score + Verdict + Next Actions
```

## 1. 실행한 명령

```
/authoring:sh-check [path/to/script.sh]
/authoring:sh-check /home/bwyoon/dotfiles/scripts/check_port_registry.sh
```

## 2. 입력

`/home/bwyoon/dotfiles/scripts/check_port_registry.sh` — 118 lines, mode 0755, executable script.
`PORTS.md` 포트 레지스트리 검증기(dEitY719/dotfiles#1154). 표 행을 `|` 로 분해해 `index` 중복을 잡고, 각 행이
decade-block 공식(`backend = 9200 + index*10`, `frontend = backend+1`, `db = backend+2`)과 맞는지 대조한다.

## 3. 결과

`Score: 1/8 checks passed (5 warnings, 2 N/A)` · `Verdict: POOR`

| 판정 | 개수 | 해당 검사 |
|------|------|-----------|
| PASS | 1 | #1 Shebang + POSIX |
| WARN | 5 | #3 Section Anatomy, #4 Naming, #8 Input Validation, #9 Verdict Output, #10 Next-action Hint |
| FAIL | 2 | #6 Help Flag, #7 UX Lib Usage |
| N-A  | 2 | #2 Interactive Guard, #5 ZSH Compat Guard |

```
| 6 | Help Flag              | FAIL   | no -h/--help arm; usage in source|
Verdict: POOR — UX layer absent: no help flag and no ux_lib, so every message is raw echo
```

근거: `grep -cE 'ux_'` → 0, `grep -cE '(echo|printf|tput) '` → 8 (L50 `printf` 는 `$()` 로 잡히는 반환값이라
허용 예외, 나머지 7개가 사용자 대면 raw echo). 감사 후 대상 파일은 무수정 — `git status` 빈 출력.
