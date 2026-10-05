---
name: sh-check
description: >-
  Audit a shell script (`*.sh`) against 10 PASS/WARN/FAIL/N/A criteria. Use on
  "check this shell script", "셸 스크립트 점검해줘", "/authoring:sh-check". Do NOT
  use for SKILL.md (authoring:skill-check) or AGENTS.md (harness:ai-context).
compatibility:
  tools: Read, Glob, Grep, Bash
  # Check 15: lib/ network hits are the linter's own detection regex and selftest fixtures — sh_check.sh never opens a connection
  network: none
metadata:
  model_recommendation:
    tier: haiku
    reason: "audit-only shell script linter; lib/sh_check.sh decides the mechanical checks, the model judges two and renders the report; bounded output"
    claude: prefer
    non_claude: advisory-only
license: MIT
---

# Shell Script Quality Auditor

## Help

If the argument is `-h`, `--help`, or `help`, read `references/help.md` and
output its content verbatim, then stop. No further checks. `references/help.md`
is also the SSOT for the accepted arguments (`[path/to/script.sh]`, `help`).

## Step 1: Locate the File

- Argument given → audit that path. Reject if it doesn't exist or doesn't
  end in `.sh`/`.bash`/`.zsh` (warn but continue if the user insists).
- No argument → search the current directory for `*.sh` files. If exactly
  one is found, audit it. If multiple, list them and ask which one. If none,
  output a help hint pointing to `/authoring:sh-check path/to/file.sh`.

## Step 2: Run 10 Quality Checks

Audit-only — never stop on a failing check. Every check produces a row, and a
check whose tooling is unavailable produces `N/A` with a note.

Run the mechanical half first. `<skill-dir>` is this skill's own installed
directory, never a path inside the repository being audited:

```sh
sh <skill-dir>/lib/sh_check.sh path/to/script.sh
```

It classifies the target file (sourced fragment vs executable script) and
prints `check<TAB>result<TAB>note` for checks 1, 2, 4, 5, 6, 7, 9 and 10,
then one `fn` row per function returning a fixed-line verdict.

Read `references/checks.md` for the criteria behind those rows and judge the
two the helper leaves to you — 3 Section Anatomy, 8 Input Validation. Do not
override rows 9 and 10. Then re-run with your two calls to get every row plus
the score and verdict:

```sh
sh <skill-dir>/lib/sh_check.sh path/to/script.sh <c3> <c8>
```

The trailing `score<TAB><pass>/<effective-total><TAB><verdict>` row is the
arithmetic from `references/report-template.md` — use it, do not re-derive it.

## Step 3: Output the Report

Read `references/report-template.md` for the exact format. The report has:

- File path + line count
- Two tables (Structure 1–5, UX 6–10) with PASS/WARN/FAIL/N/A + notes
- A Verdict Functions table from the `fn` rows, when there are any
- Score line: `X/10 checks passed (Y warnings, Z N/A)`
- **Verdict** — the word from the helper's `score` row: `EXCELLENT` / `GOOD` /
  `NEEDS WORK` / `POOR`.
- **Next Actions** — one bullet per WARN/FAIL with a concrete fix command
  or code snippet. Each bullet is anchored by `[<LEVEL> #N]` so the user
  can map back to the table.

Do NOT recommend changes for PASS or N/A rows.

## Constraints

- Read-only audit — never edit the target file.
- Quote actual file lines when describing problems in Next Actions.
- The concrete pattern printed in each `references/checks.md` entry is the
  bar. Do not send the user to a file outside the audited repository.

## Related Skills

Mirrors `authoring:skill-check`, which audits `SKILL.md` files instead of `.sh` files.
`harness:ai-context check` audits `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`.
