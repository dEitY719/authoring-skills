# authoring:sh-check — Report Template

Use this exact format when outputting the audit report.

The example below is real output: `lib/sh_check.sh` run on gwt with the
auditor's calls `PASS PASS` for checks 3 and 8. Reproduce it with the file
saved under a path that still contains `shell-common/functions/` (the helper
classifies by location):

```sh
gh api 'repos/dEitY719/dotfiles/contents/shell-common/functions/git_worktree.sh?ref=89c276329ca4b2cd5be657b74b79602bc36364e9' \
  --jq .content | base64 -d > <dir>/shell-common/functions/git_worktree.sh
sh lib/sh_check.sh <dir>/shell-common/functions/git_worktree.sh PASS PASS
```

```
## authoring:sh-check Report
File: shell-common/functions/git_worktree.sh
Lines: 2627
Class: sourced fragment

### Structure Checks
| # | Check                  | Result | Notes                                              |
|---|------------------------|--------|----------------------------------------------------|
| 1 | Shebang + POSIX        | FAIL   | shell-common file uses 1 bash-only construct(s)    |
| 2 | Interactive Guard      | PASS   | guard within the first 10 lines                    |
| 3 | Section Anatomy        | PASS   | auditor judgment                                   |
| 4 | Naming Convention      | PASS   | 54 function(s), all snake_case                     |
| 5 | ZSH Compat Guard       | WARN   | emulate -L sh in 9 of 33 function(s) that need it  |

### UX Quality Checks
| # | Check                  | Result | Notes                                              |
|---|------------------------|--------|----------------------------------------------------|
| 6 | Help Flag              | PASS   | -h/--help delegates to a help function             |
| 7 | UX Lib Usage           | WARN   | 52 raw echo/printf line(s) alongside 362 ux_* call(s) |
| 8 | Input Validation       | PASS   | auditor judgment                                   |
| 9 | Verdict Output         | PASS   | 3-line verdict, state case, split render           |
|10 | Next-action Hint       | WARN   | 1 of 11 NEXT value(s) not a command                |

Score: 6/10 checks passed (3 warnings, 0 N/A)
Verdict: NEEDS WORK — one POSIX FAIL plus zsh-guard and raw-output gaps

### Next Actions
1. [FAIL #1] The one hit is line 196:
     sed -n 's/^gitdir:[[:space:]]*//p' "$1"
   `[[:space:]]` is a POSIX bracket class, not `[[ ]]` — confirm by eye
   before changing anything.
2. [WARN #5] Open each of the 24 functions that need the guard and lack it
   with:
     [ -n "${ZSH_VERSION-}" ] && emulate -L sh
3. [WARN #7] Route the 52 raw echo/printf lines through ux_info / ux_bullet /
   ux_error.
4. [WARN #10] Make the `dirty` NEXT a command:
     printf '%s\n%s\n%s\n' "dirty" "$_age" "commit or stash"
Run /authoring:sh-check again after fix to verify.
```

---

## Verdict Computation

`lib/sh_check.sh` implements this table and prints the result as its `score`
row. Map `PASS_COUNT` (out of `10 - NA_COUNT`) to a verdict:

| PASS / Effective Total | Verdict      | Meaning                                     |
|------------------------|--------------|---------------------------------------------|
| 100%                   | EXCELLENT    | Reference-quality — nothing to fix          |
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
- Notes column: `lib/sh_check.sh`'s note verbatim for the rows it decides;
  for the two judged rows (3, 8), ≤ 40 chars.
- Quote actual file lines in the Next Actions section, not in the table.
- Do NOT add filler prose ("the script looks great!") — the Verdict line
  already classifies overall quality.
- If `Score = 10/10` (no WARN, no FAIL), Next Actions section reads:
  `No actions required.`
