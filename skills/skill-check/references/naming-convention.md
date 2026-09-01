# Skill Naming Convention — `category:action` Colon Form Preferred

This user's SSOT (`~/dotfiles/claude/skills/`) uses **`category:action`** in
the `name:` frontmatter field, and the **kebab form** for the folder name.
The colon is intentional. Audits must report it as PASS, not WARN.

## Rule

| frontmatter `name:` | folder name |
|---|---|
| `gh:commit` | `gh-commit/` |
| `gh:pr` | `gh-pr/` |
| `gh:pr-reply` | `gh-pr-reply/` |
| `gh:issue-create` | `gh-issue-create/` |
| `skill:refactor` | `skill-refactor/` |
| `skill:check` | `skill-check/` |
| `skill:create` | `skill-create/` |
| `ai-worktree:spawn` | `ai-worktree-spawn/` |
| `ai-worktree:teardown` | `ai-worktree-teardown/` |
| `write:insight` | `write-insight/` |

14+ skills already follow this form. Mixing kebab and colon fragments the
mental model.

## Why colon

- **Memorable grouping**: `gh:*` = GitHub actions, `skill:*` = skill
  maintenance, `ai-worktree:*` = worktree lifecycle. Users tab-complete
  or recall by category.
- **User-stated preference** (2026-04): "category:actions 형태는 기억하기
  쉬운 이점이 있음."

## Common false alarms — DO NOT downgrade to WARN/FAIL on these

- **VS Code Anthropic Agent extension** flags `name: foo:bar` and
  `name`/folder mismatch as diagnostics. These are **cosmetic only** —
  Claude Code CLI accepts both, and 14+ live skills prove it.
- **Anthropic-published skills** (`document-skills/*`) use kebab-only.
  That is Anthropic's house style, not a CLI requirement. The user's SSOT
  has its own convention.
- **"Verb-first names not allowed"** is a myth. `write:insight` works
  fine — any rejection some tool cites is purely the colon character, not
  the verb.

## Audit rule for Check 3 (Frontmatter Validity)

- Colon in `name:` → **PASS**.
- Folder/name kebab-vs-colon mismatch → **PASS** when the folder is the
  kebab form of the colon name (e.g., `name: gh:pr` + folder `gh-pr/`).
- Only flag when the skill's `name:` deviates from BOTH conventions
  (neither colon SSOT form nor consistent kebab) — that is genuine
  inconsistency.

## History

This file exists because the colon-naming question came up twice in
quick succession (2026-04). The first time, the assistant proposed
kebab "fix" based on a VS Code diagnostic; the user pushed back with the
correct reasoning. Recording here so the same mistake is not made again.
