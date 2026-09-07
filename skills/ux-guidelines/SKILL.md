---
name: ux-guidelines
description: >-
  Apply UX_GUIDELINES.md to shell functions and help text — replace raw
  echo/printf/ANSI with semantic ux_lib calls (ux_header, ux_section,
  ux_bullet). Use on "/authoring:ux-guidelines", "help 함수 UX 가이드라인대로
  리팩터링", or a bulk shell-common UX review.
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
metadata:
  model_recommendation:
    tier: sonnet
    reason: "convention-driven refactoring"
    claude: prefer
    non_claude: advisory-only
license: MIT
---

# UX Guidelines Skill

## Help

If the argument is `-h`, `--help`, or `help`, read `references/help.md` and output it verbatim, then stop.

## Objective

Enforce `$SHELL_COMMON/tools/ux_lib/UX_GUIDELINES.md` for user-facing shell output.
`SHELL_COMMON` defaults to `$HOME/dotfiles/shell-common` — every `shell-common/`
path in this skill is relative to the `dEitY719/dotfiles` checkout, and resolves
to nothing anywhere else.
Keep implementations semantic (`ux_*`), readable, and cross-shell compatible.

Read `references/ux-foundation.md` for principles, color semantics, and UX function
selection rules.

## Mode Selection

Choose one mode before editing:

1. **Individual function refactoring**: a specific function/module is requested.
2. **Bulk compliance review**: user asks to scan a shell tree (default
   `$SHELL_COMMON`) and write findings to `docs/abc-review-*.md`.

## Mode A: Individual Function Refactoring

Read `references/refactoring-playbook.md` when executing this mode.

1. Read the target module and locate hardcoded output patterns.
2. Build a section map: header, grouped commands, procedures, warnings, tips.
3. Ensure `ux_lib` is loaded with the approved conditional pattern.
4. Replace hardcoded output (`cat <<EOF`, ANSI codes, raw status strings) with
   semantic UX functions.
5. Keep command behavior unchanged; refactor presentation only unless user asked
   for behavior changes.
6. Validate in both bash and zsh; run targeted help function checks.
7. Report changes with file paths, key replacements, and validation results.

Stop on first failure and report — do not proceed to the next step.

## Mode B: Bulk UX Compliance Review

Read `references/bulk-review-workflow.md` when executing this mode.

1. Run `sh <skill-dir>/lib/scan-ux.sh [path ...]` — it walks the given files and
   directories (default `$SHELL_COMMON`) and prints one
   `file<TAB>line<TAB>pattern<TAB>severity` row per mechanical hit. Pass the
   user's scope as the argument; do not assume `shell-common/`.
2. Judge each row: apply the exclusions, drop false positives, and add the
   findings only a reader can see (missing help discoverability, inconsistent
   grouping).
3. Write the report to the requested file (`docs/abc-review-C.md`,
   `docs/abc-review-CX.md`, or `docs/abc-review-G.md`).
4. Include concrete file/line evidence and suggested fixes.
5. Do not commit unless explicitly requested.

Audit mode — scan the entire scope and report every finding. Do NOT stop on
the first violation; Mode B is read-only and the report must be complete.

## Output

List remaining risks and follow-up commands below the block.

```
[OK] authoring:ux-guidelines — mode=<a|b> files_changed=<n> validated=<true|false>

Next: mise run lint-sh && ./tests/test
```
