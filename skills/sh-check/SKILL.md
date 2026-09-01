---
name: sh-check
description: >-
  Audit a shell script (`*.sh`) against the dotfiles quality bar — 10
  PASS/WARN/FAIL/N/A criteria. Use on "check this shell script",
  "셸 스크립트 점검해줘", "/authoring:sh-check". Do NOT use for SKILL.md
  (use `authoring:skill-check`) or AGENTS.md (use `devx:ai-context`).
compatibility:
  tools: Read, Glob, Grep, Bash
metadata:
  model_recommendation:
    tier: haiku
    reason: "audit-only shell script linter; read-only pattern matching against git_worktree.sh canonical reference; bounded output"
    claude: prefer
    non_claude: advisory-only
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

Record:
- `LINES` — `wc -l` of the target file
- `IS_SOURCED` — heuristic: file is sourced if it lives under
  `shell-common/functions/`, `bash/`, `zsh/`, or contains
  `case $- in *i*)` near the top. Otherwise treat as an executable script.

## Step 2: Run 10 Quality Checks

Read `references/checks.md` for the full criteria. Each check returns one of:

- **PASS** — meets the bar
- **WARN** — partial / minor issue
- **FAIL** — missing or violates rule
- **N/A** — not applicable for this file class (e.g. interactive guard on
  an executable script, ZSH guard on a bash-only script)

The 10 checks are split into two groups:

**Structure (1–5)**
1. Shebang + POSIX Hygiene
2. Interactive Guard
3. Section Anatomy
4. Naming Convention
5. ZSH Compat Guard

**UX Quality (6–10)**
6. Help Flag
7. UX Lib Usage
8. Input Validation
9. Verdict Output
10. Next-action Hint

Each check definition lists the concrete grep patterns / structural cues to
look for. Treat `git_worktree.sh` as the canonical example — when the
target file uses the same pattern, that check passes.

## Step 3: Output the Report

Read `references/report-template.md` for the exact format. The report has:

- File path + line count
- Two tables (Structure 1–5, UX 6–10) with PASS/WARN/FAIL/N/A + notes
- Score line: `X/10 checks passed (Y warnings, Z N/A)`
- **Verdict** — single-line classification: `EXCELLENT` / `GOOD` /
  `NEEDS WORK` / `POOR`. Computed from Score per the table in
  `references/report-template.md`.
- **Next Actions** — one bullet per WARN/FAIL with a concrete fix command
  or code snippet. Each bullet is anchored by `[<LEVEL> #N]` so the user
  can map back to the table.

Do NOT recommend changes for PASS or N/A rows. Do NOT add filler "looks
great!" prose — the table and Verdict speak for themselves.

## Constraints

- Read-only audit — never edit the target file.
- Quote actual file lines when describing problems in Next Actions.
- If a check needs a tool the environment lacks (e.g. no `grep`), report
  N/A with an explanatory note rather than failing silently.
- The canonical reference is `shell-common/functions/git_worktree.sh`. When
  in doubt about whether a pattern is "the right way", compare to it.

## Related Skills

Mirrors `authoring:skill-check`, which audits `SKILL.md` files instead of `.sh` files.
`devx:ai-context check` audits `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`.
