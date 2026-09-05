# authoring:command-rename — Help

## Synopsis

`/authoring:command-rename <command-family> <desired-convention> [remote]`

Designs a command-naming refactor and files the tracking issue(s). It does
NOT rename anything or commit — the actual rename runs later via
`/gh-flow:issue <the-refactor-issue-number>`.

## Arguments

| # | Name | Default | Description |
|---|------|---------|-------------|
| 1 | `<command-family>`, or `-h`/`--help`/`help` | — | Command/alias family to rename (e.g. `agy`). Ambiguous → candidates are shown, no guess. |
| 2 | `<desired-convention>` | — | Target naming convention (e.g. `dash-form`, `snake_case`, `<tool>-<noun>`). |
| 3 | `[remote]` | `origin` | Git remote whose repo will own the new issue(s). Missing remote fails fast. |

## Examples

- `/authoring:command-rename agy dash-form` — design `agy` → dash-form rename, file a `refactor` issue on `origin`.
- `/authoring:command-rename agy dash-form upstream` — same, issue on the `upstream` remote's repo.
- `/authoring:command-rename my_tool "<tool>-<noun>"` — convention not codified in SSOT → also files a cross-linked `docs` issue for the rule gap.
- `/authoring:command-rename -h` / `--help` / `help` — print this help.

## What it produces

- One `refactor` GitHub issue (mapping table, before/after, behavior-preservation, risk/rollback, verification).
- Plus, only when a rule gap is detected, one `docs` GitHub issue, cross-linked with the refactor issue.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Issue(s) created; report printed with URLs. |
| 1 | Precondition failure (not a git repo, remote not found, `gh auth` failure, or `gh-issue:create` failed). |
| 2 | Missing/invalid required argument (`<command-family>` or `<desired-convention>`). |

## Not in scope

- No renaming, no source edits, no commits.
- No delivery-model change (function vs PATH-executable) — see `references/ssot-check.md`.
