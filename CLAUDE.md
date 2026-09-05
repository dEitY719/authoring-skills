# authoring-skills — Contributor Guidelines

This file is the AI context document for this repo. `AGENTS.md` is a symlink to
it, so Claude Code, Codex, Gemini CLI, and every other harness read the same
text. Edit `CLAUDE.md`; never replace the symlink with a second copy.

## What this repo is

A single-plugin skill marketplace. The plugin is named `authoring` and it
bundles six skills for the source material an AI harness itself reads — skill
files, shell scripts, help text, command names:

| Skill | Role |
|-------|------|
| `skill-create` | Build a new SKILL.md through interview, draft, eval loop, description tuning, and packaging. |
| `skill-check` | Audit one SKILL.md against 16 structure, UX, model, security, and context-budget checks. Read-only. |
| `skill-refactor` | Shrink an over-long SKILL.md under 100 lines by extracting detail into `references/`. |
| `sh-check` | Audit a `*.sh` file against 10 PASS/WARN/FAIL/N-A criteria. Read-only. |
| `ux-guidelines` | Replace raw `echo`/`printf`/ANSI in shell help text with semantic `ux_lib` calls. |
| `command-rename` | Design a command-naming refactor and file the tracking issue(s) — never touches code. |

Three write, three only audit. Every skill states which it is before it starts;
do not blur that line when editing one.

The skills were extracted from `dEitY719/dotfiles`
(`claude/skills/{skill-create,skill-check,skill-refactor,sh-check,devx-ux-guidelines,devx-command-rename}`)
as a snapshot — see the first commit for the source SHA. The `devx-` prefix is
dropped here because the plugin namespace (`authoring:`) now supplies it. The
dotfiles copies remain in place for now; they are removed in a later phase of
that repo's migration plan (dEitY719/dotfiles#1410 Phase 4).

## Layout: root manifests, one flat `skills/`

This repo deliberately does **not** use the nested `plugins/<name>/skills/`
"mono" layout. Every harness manifest sits at the repo root and points at a
single flat `./skills/` directory:

```
.claude-plugin/{marketplace,plugin}.json   Claude Code
.codex-plugin/plugin.json                  Codex
.kimi-plugin/plugin.json                   Kimi CLI
.hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
.opencode/plugins/authoring.js             OpenCode
.agents/plugins/marketplace.json           Antigravity
gemini-extension.json + GEMINI.md          Gemini CLI
skills/<name>/SKILL.md                     the skills themselves
```

Only Claude Code understands the nested mono layout. The other five harnesses
resolve manifests at the repo root and a skills tree at `./skills/`, so nesting
would silently cut this plugin down to Claude-Code-only. **Do not move the
manifests under a `plugins/` directory.**

## Shared assets live in `harness-skills` — link, never copy

Two things this repo depends on are owned by `dEitY719/harness-skills`
(dEitY719/dotfiles#1410 F-5 / D-10):

1. **Per-harness tool mappings** — `references/{codex,kimi,gemini,antigravity,hermes,opencode}-tools.md`.
   This repo carries no `references/` tree of its own; `GEMINI.md`,
   `.opencode/INSTALL.md`, and `.kimi-plugin/plugin.json` link there instead.
   If you are about to paste one in, stop and add a link — one tool rename must
   stay one edit, not fifteen (NF-2).
2. **The CI workflow** — `.github/workflows/skill-check.yml`. This repo's
   `validate.yml` calls it with `plugin-name: authoring`. Do not re-inline the
   checks here; to change what is checked, open a PR against `harness-skills`.

## The `skill-check` name appears twice

The reusable CI workflow this repo calls is named `skill-check`, and one of the
six skills is also named `skill-check`. That is a name collision, not a circular
dependency, and nothing here validates itself:

- **`.github/workflows/skill-check.yml`** is a GitHub Actions job owned by
  `harness-skills`. It runs on GitHub's runners, parses manifests, and counts
  lines. It knows nothing about this repo's contents beyond the file layout.
- **`skills/skill-check/SKILL.md`** is an authoring/audit procedure a model
  follows when a human points it at some *other* repo's SKILL.md. It never runs
  in CI.

Different layers, different runtimes, different inputs. When you change one, you
have not changed the other — and when CI fails, the fix is in the tree or in
`harness-skills`, never in `skills/skill-check/`.

## Rules for changing skills

- **Skill directory name is the identity.** `skills/<name>/` must match the
  `name:` field in that skill's `SKILL.md` frontmatter, and that field is the
  **bare** name (`skill-check`), never namespaced (`authoring:skill-check`, and
  emphatically not the dotfiles-era `skill:check`). CI fails on a `:` in
  `name:`. The harness supplies the `authoring:` prefix at invocation time.
- **Invocation form in prose is namespaced.** Body text referring to a skill as
  a command writes `/authoring:skill-check`. The dotfiles-era `/skill:check`,
  `/sh:check`, `/devx:ux-guidelines`, and `/devx-command-rename` forms are dead
  here. The one deliberate exception is
  `skills/{skill-check,skill-refactor}/references/naming-convention.md`, whose
  table quotes the dotfiles colon convention as its subject matter.
- **Progressive disclosure.** `SKILL.md` stays under 100 lines (CI enforces it)
  and names which `references/` file to read and when. Detail lives in that
  skill's own `references/`. Do not inline a reference file back into
  `SKILL.md`. `skill-refactor` is the skill that performs this operation on
  other repos — apply it here too.
- **Description budget.** CI sums every skill description and fails past 5,440
  characters — Codex's context budget — and rejects any single description over
  1,024. Keep new descriptions tight.
- **Honour each skill's safety contract.** `skill-check` and `sh-check` are
  read-only and must report every criterion rather than stopping at the first
  failure. `skill-refactor` presents a plan and waits before writing.
  `command-rename` files issues and renames nothing.
- **Helpers stay executable.** `skills/skill-create/{scripts,eval-viewer}/`
  hold real Python entry points. Prefer fixing a helper over describing the fix
  in prose — that is the rule `skill-create` itself teaches.

## Emojis

Not in prose, manifests, or workflow files — token efficiency, same rule as the
upstream dotfiles repo. The gate bans any codepoint at or above `U+1F000` plus
`U+FE0F`; typographic marks such as `✓ ✗ ✅ ❌` sit below that and are fine.

**One exception:** `skills/skill-check/references/` contains emoji as *subject
matter*. That skill's Check 11 documents the repo-wide emoji ban and its single
sanctioned exception — the three `ai-metrics` footer glyphs (dEitY719/dotfiles#317 F-2,
PR #320, #367) — and `references/allowed-emoji-skills.txt` is the
allowlist data behind it. A policy you cannot read is not a policy, so CI's
emoji gate is passed `allow-emoji-paths: skills/skill-check/references/` for
exactly that reason. Do not widen the allowlist; do not add emoji anywhere else.

## Version bumps

The version appears in seven manifests: `.claude-plugin/marketplace.json`,
`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
`.kimi-plugin/plugin.json`, `.hermes-plugin/plugin.yaml`,
`gemini-extension.json`, and `package.json`. CI checks that they agree — bump
all of them together. Versioning is independent per repo
(dEitY719/dotfiles#1410 D-9); this repo does not move in lockstep with its
siblings.
