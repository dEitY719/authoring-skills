# authoring:sh-check — Report Template

Use this exact format when outputting the audit report.

```
## authoring:sh-check Report
File: <path>
Lines: <count>
Class: <sourced fragment | executable script | bash-only | zsh-only>

### Structure Checks
| # | Check                  | Result | Notes                            |
|---|------------------------|--------|----------------------------------|
| 1 | Shebang + POSIX        | PASS   | #!/bin/sh, POSIX syntax          |
| 2 | Interactive Guard      | WARN   | sourced file, no case $- guard   |
| 3 | Section Anatomy        | PASS   | ===…=== + Usage + Args           |
| 4 | Naming Convention      | PASS   | _gwt_ private, gwt_ public       |
| 5 | ZSH Compat Guard       | PASS   | emulate -L sh in exposed funcs   |

### UX Quality Checks
| # | Check                  | Result | Notes                            |
|---|------------------------|--------|----------------------------------|
| 6 | Help Flag              | PASS   | -h/--help → _gwt_help_*          |
| 7 | UX Lib Usage           | PASS   | ux_header/info/error throughout  |
| 8 | Input Validation       | PASS   | required args, mutex, unknown    |
| 9 | Verdict Output         | PASS   | state+age+next 3-line structure  |
|10 | Next-action Hint       | PASS   | teardown/push/etc per state      |

Score: 9/10 checks passed (1 warning, 0 N/A)
Verdict: GOOD — production-ready, minor polish needed

### Next Actions
1. [WARN #2] Add interactive guard at top of file:
     case $- in *i*) ;; *) [ -n "${DOTFILES_FORCE_INIT-}" ] || return 0 ;; esac
   Run /authoring:sh-check again after fix to verify.
```

---

## Verdict Computation

Map `PASS_COUNT` (out of `10 - NA_COUNT`) to a verdict:

| PASS / Effective Total | Verdict      | Meaning                                     |
|------------------------|--------------|---------------------------------------------|
| 100%                   | EXCELLENT    | Reference-quality — could replace git_worktree.sh as canonical example |
| ≥ 80% AND no FAIL      | GOOD         | Production-ready, minor polish needed       |
| ≥ 60% OR exactly 1 FAIL| NEEDS WORK   | Functional but several gaps                 |
| < 60% OR ≥ 2 FAILs     | POOR         | Major rework required                       |

The Verdict line uses one of these four words exactly, followed by an
em-dash and a one-line summary tailored to the dominant issue class
(structure vs UX).

---

## Next Actions Rules

- **One bullet per WARN and FAIL** — never per PASS or N/A.
- Each bullet starts with `[<LEVEL> #<N>]` so the user can map back to
  the table.
- Provide a concrete fix:
  - For structural issues — paste the exact line/snippet to add.
  - For UX issues — name the ux_* function or pattern to adopt.
- End the Next Actions section with:
  `Run /authoring:sh-check again after fix to verify.`

---

## Output Rules

- Tables MUST use the columns shown above (`#`, `Check`, `Result`, `Notes`).
- Result column values: `PASS` / `WARN` / `FAIL` / `N/A` (uppercase).
- Notes column ≤ 40 chars — concise enough to fit a terminal.
- Quote actual file lines in the Next Actions section, not in the table.
- Do NOT add filler prose ("the script looks great!") — the Verdict line
  already classifies overall quality.
- If `Score = 10/10` (no WARN, no FAIL), Next Actions section reads:
  `No actions required.`
