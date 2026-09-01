/authoring:sh-check — Audit a shell script (`*.sh`) against the dotfiles quality bar

Usage:
  /authoring:sh-check [path/to/script.sh]
  /authoring:sh-check help

Arguments:
  [path]    Path to the shell script to audit (optional)
            If omitted, searches the current directory for *.sh files

Options:
  -h, --help, help   Print this help and stop. No checks are run.

What it checks (10 criteria, modeled on git_worktree.sh):

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
    9. Verdict Output            — explicit state + structured key:value
   10. Next-action Hint          — success output points to next command

Each check reports PASS / WARN / FAIL / N/A.

Examples:
  /authoring:sh-check shell-common/functions/git_worktree.sh
  /authoring:sh-check bash/utils/my_function.sh
  /authoring:sh-check
  /authoring:sh-check help

Output:
  - Two tables (Structure, UX Quality) with results + notes
  - Score: X/10 checks passed (Y warnings, Z N/A)
  - Verdict: EXCELLENT / GOOD / NEEDS WORK / POOR
  - Next Actions: concrete fixes for every WARN and FAIL

Companion skills:
  /authoring:skill-check         — audit a SKILL.md file (Progressive Disclosure)
  /devx:ai-context check — audit an AGENTS.md, CLAUDE.md, or GEMINI.md file
