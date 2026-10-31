/authoring:sh-check — Audit a shell script (`*.sh`) against 10 quality criteria and 4 Safety checks

Usage:
  /authoring:sh-check [path/to/script.sh]
  /authoring:sh-check help

Arguments and options:

| Option | Description | Default |
|--------|-------------|---------|
| `[path]` | Shell script to audit. | search `./` for `*.sh`; ask if several |
| `-h`, `--help`, `help` | Print this help and stop. No checks are run. | — |

What it checks (10 criteria):

  Structure (1–5)
    1. Shebang + POSIX Hygiene   — #!/bin/sh, [ ], >/dev/null 2>&1
    2. Interactive Guard         — case $- in *i*) ;; *) [ -n "${DOTFILES_FORCE_INIT-}" ] || return 0 ;; esac
    3. Section Anatomy           — # ====== headers + Usage: + Args:
    4. Naming Convention         — _prefix private, snake_case
    5. ZSH Compat Guard          — emulate -L sh in cross-shell functions

  UX Quality (6–10)
    6. Help Flag                 — -h/--help → structured help, return 0
    7. UX Lib Usage              — ux_header/ux_info/ux_error/ux_success
    8. Input Validation          — required args, mutex flags, unknown opts
    9. Verdict Output            — printf 3-line state/age/next + state case
   10. Next-action Hint          — NEXT is a runnable command, `-` if terminal

  Safety (11–14, scored apart, never in the Verdict)
   11. Temp File Cleanup         — mktemp paths, rm reached from an EXIT trap
   12. Atomic Write              — same-directory mktemp + mv, no direct >
   13. Signal Handling           — INT and TERM trapped, background jobs stopped
   14. Dry-run Support           — --dry-run, -n or --apply read in a condition

Each check reports PASS / WARN / FAIL / N/A.

Examples:
  /authoring:sh-check scripts/deploy.sh
  /authoring:sh-check shell-common/functions/gwt.sh
  /authoring:sh-check
  /authoring:sh-check help

Checks 1, 2, 4, 5, 6, 7, 9, 10 and 11–14 are decided by lib/sh_check.sh, which
also computes the score and verdict; 3 and 8 are the auditor's judgment.

Output:
  - Three tables (Structure, UX Quality, Safety) with results + notes
  - Score: X/10 checks passed (Y warnings, Z N/A)
  - Safety: X/Y checks passed (W warnings, Z N/A), or Safety: N/A
  - Verdict: EXCELLENT / GOOD / NEEDS WORK / POOR
  - Next Actions: concrete fixes for every WARN and FAIL

Companion skills:
  /authoring:skill-check         — audit a SKILL.md file (Progressive Disclosure)
  /harness:ai-context check     — audit an AGENTS.md, CLAUDE.md, or GEMINI.md file
