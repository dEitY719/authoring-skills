---
name: command-rename
description: >-
  Design a command-naming refactor and file the tracking issue(s) — never
  touch code. Use on /authoring:command-rename, /authoring:command-rename,
  "명령 네이밍 통일 이슈 만들어", "rename this command family". The rename
  itself runs later via /gh-flow:issue.
allowed-tools: Bash, Read, Grep, Agent
metadata:
  model_recommendation:
    tier: sonnet
    reason: "discovery + SSOT diff + interactive mapping design; delegates issue creation"
    claude: prefer
    non_claude: advisory-only
license: MIT
---

# authoring:command-rename — Naming refactor → tracking issue(s)

## Role

From a target command family and a desired naming convention, design an
old→new rename mapping, check it against the naming SSOT, flag any rule gap,
and file the `refactor` (and gap-only `docs`) issue via [[gh-issue-create]].
Design and file only — no code edits, no commits. The rename itself is a
separate later `/gh-flow:issue` run.

## Help

If arg #1 is `-h`, `--help`, or `help`, read `references/help.md` and output
its content verbatim, then stop. No API calls. That file is the SSOT for the
argument surface: `<command-family> <desired-convention> [remote]` plus
`-h`/`--help`/`help`.

## Step 1: Parse input & resolve target family

Parse `<command-family>` (e.g. `agy`), `<desired-convention>` (e.g.
`dash-form`), optional `[remote]` (default `origin`). Resolve `TARGET_REPO` per `references/repo-resolution.md`
(fail-fast on a missing remote). If the family is ambiguous or matches
nothing, present the candidate names you found and ask — never guess.

## Step 2: Discover definitions + ALL reference points

Follow `references/discovery.md` verbatim: locate alias/function definitions
and every reference-point category (inline help/DOC blocks, `install_*.sh`,
`my_help.sh` registration, `zz_help_standard_adapter.sh`, help tests, bats).
Omitting a category leaves dangling references after the rename.

## Step 3: Compare against SSOT + detect rule gap

Follow `references/ssot-check.md`: read and cite all three docs, which live in
the `dEitY719/dotfiles` checkout (`$DOTFILES_ROOT`, default `$HOME/dotfiles`) —
`docs/.ssot/command-design-pattern.md`, `command-guidelines.md`,
`command-delivery-model.md`. If the requested convention is not literally
covered by an existing SSOT section, that is a **rule gap** — record it. Do
not invent SSOT text.

## Step 4: Exclude git-family abbreviations

Drop `gb`, `gwt`, and other high-frequency git abbreviations from the rename
candidate set regardless of the requested convention
(`references/discovery.md` → git-family exception).

## Step 5: Design the mapping (interactive)

Follow `references/mapping-design.md`: build the old→new table, then get the
user's explicit decision on backward-compat (deprecated shim per
`command-design-pattern.md` §8 vs hard removal) and on any name collisions.
List intentionally-dropped names. Never auto-decide these — confirm first.

## Step 6: Create the issue(s) via gh-issue:create

Follow `references/issue-creation.md`. Create the `refactor` issue by
`Skill(gh-issue:create, ...)` with explicit "refactor" intent so its
classifier picks the `refactor` template. **Only if Step 3 found a rule
gap**, also create a `docs` issue the same way, then cross-link both
(`gh issue comment <A> --body "Related: #<B>"` each way). Never call
`gh issue create` directly here.

## Step 7: Report

Format per `references/report-template.md`: created issue number(s) + URL(s),
an `[OK]`/`[FAIL]` verdict, and a `Next:` hint pointing at
`/gh-flow:issue <refactor-issue-number>`.

## Constraints

See `references/constraints.md` (no source edits/commits, never skip the
git-family exclusion, never invent SSOT text, always confirm
backward-compat/collision decisions, docs issue only on a real gap).

## Related Skills

Issue creation is delegated to [[gh-issue-create]] (never `gh issue create`
directly). The rename this skill designs is executed later by a separate
`/gh-flow:issue <refactor-issue-number>` run — this skill never edits code.
