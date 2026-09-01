# authoring-skills

Six skills for the artifacts an AI coding harness reads about itself — the
`SKILL.md`, the shell script, the help text, the command name. Packaged as a
single plugin named `authoring`, installable on six coding-agent harnesses.

Three of them audit and never write; three of them rewrite and say so first.

## Skills

| Skill | Invoke | What it does |
|-------|--------|--------------|
| `skill-create` | `/authoring:skill-create ["<idea>"]` | Builds a skill through eight phases — capture intent, interview, draft, run and evaluate test cases, improve, tune the description for triggering accuracy, package, then gate on `skill-check`. |
| `skill-check` | `/authoring:skill-check [path/to/SKILL.md] [--recursive]` | Audits one `SKILL.md` against 16 checks across structure, UX quality, model-tier metadata, security declarations, and the context budget. Reports PASS/WARN/FAIL/N-A for every one. Read-only. |
| `skill-refactor` | `/authoring:skill-refactor [path/to/SKILL.md]` | Shrinks an over-long `SKILL.md` under 100 lines by extracting detail into `references/`. Presents the plan and waits for confirmation before writing. |
| `sh-check` | `/authoring:sh-check [path/to/script.sh]` | Audits a `*.sh` file against 10 criteria — POSIX hygiene, interactive guard, section anatomy, naming, zsh compat, help flag, `ux_lib` usage, input validation, verdict output, next-action hint. Read-only. |
| `ux-guidelines` | `/authoring:ux-guidelines [target]` | Replaces raw `echo`/`printf`/ANSI in shell functions and help text with semantic `ux_lib` calls (`ux_header`, `ux_section`, `ux_bullet`). Single-function or bulk-sweep mode. |
| `command-rename` | `/authoring:command-rename <command-family> <convention> [remote]` | Designs a command-naming refactor — mapping table, behaviour preservation, risk and rollback — and files the tracking issue(s). Renames nothing; the rename runs later via `/gh:issue-flow`. |

### Visual guides and worked examples (GitHub Pages)

- `skill-create` — [visual guide](https://deity719.github.io/authoring-skills/skill-guides/skill-create.html) · [usage example](https://deity719.github.io/authoring-skills/skill-output/skill-create-usage.html) (한 문장짜리 아이디어 → 검증·패키징된 스킬)
- `skill-check` — [visual guide](https://deity719.github.io/authoring-skills/skill-guides/skill-check.html) · [usage example](https://deity719.github.io/authoring-skills/skill-output/skill-check-usage.html) (SKILL.md → 16개 항목 감사 리포트)
- `skill-refactor` — [visual guide](https://deity719.github.io/authoring-skills/skill-guides/skill-refactor.html) · [usage example](https://deity719.github.io/authoring-skills/skill-output/skill-refactor-usage.html) (100줄 초과 SKILL.md → 100줄 이하 + references/)
- `sh-check` — [visual guide](https://deity719.github.io/authoring-skills/skill-guides/sh-check.html) · [usage example](https://deity719.github.io/authoring-skills/skill-output/sh-check-usage.html) (셸 스크립트 → 10개 기준 감사 리포트)
- `ux-guidelines` — [visual guide](https://deity719.github.io/authoring-skills/skill-guides/ux-guidelines.html) · [usage example](https://deity719.github.io/authoring-skills/skill-output/ux-guidelines-usage.html) (raw echo 스크립트 → ux_lib 스크립트)
- `command-rename` — [visual guide](https://deity719.github.io/authoring-skills/skill-guides/command-rename.html) · [usage example](https://deity719.github.io/authoring-skills/skill-output/command-rename-usage.html) (명령 패밀리 → 리네임 설계 + 추적 이슈)

### Picking between them

The discriminator is **what you are pointing at**:

| Artifact | Audit it | Rewrite it |
|---|---|---|
| a `SKILL.md` | `skill-check` | `skill-refactor`, or `skill-create` to make a new one |
| a `*.sh` file | `sh-check` | `ux-guidelines` (its user-facing output) |
| a command / alias name | — | `command-rename` (files an issue, does not rename) |

Run `skill-check` before `skill-refactor` — the audit tells you whether the
rewrite is needed, and `skill-create` runs that same gate itself as its Phase 8.

For `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` you want a different plugin:
`harness:ai-context` in the sibling
[`dEitY719/harness-skills`](https://github.com/dEitY719/harness-skills).

## Install

### Claude Code

```
/plugin marketplace add dEitY719/authoring-skills
/plugin install authoring@authoring-skills
```

### Codex

```
codex plugin install dEitY719/authoring-skills
```

### Kimi CLI

```
kimi plugin install dEitY719/authoring-skills
```

### Hermes Agent

```
hermes plugins install dEitY719/authoring-skills
```

### OpenCode

See [`.opencode/INSTALL.md`](.opencode/INSTALL.md).

### Gemini CLI / Antigravity

```
gemini extensions install https://github.com/dEitY719/authoring-skills
```

Antigravity (`agy`) shares `~/.gemini`, so it inherits the install.

## Harness support

These skills are written in Claude Code's vocabulary, but most of the work is
read-file / write-markdown / run-a-command, so they port cleanly. The
per-harness tool mappings and capability gaps are documented once, in
[`dEitY719/harness-skills/references/`](https://github.com/dEitY719/harness-skills/tree/main/references)
(#1410 F-5); read the one file for the harness you are on.

| Skill | Claude Code | Codex | Kimi | Gemini / Antigravity | Hermes | OpenCode |
|-------|:-----------:|:-----:|:----:|:--------------------:|:------:|:--------:|
| `skill-create` | full | partial | partial | partial | partial | partial |
| `skill-check` | full | full | full | full | full | full |
| `skill-refactor` | full | full | full | full | full | full |
| `sh-check` | full | full | full | full | full | full |
| `ux-guidelines` | full | full | full | full | full | full |
| `command-rename` | full | full | full | full | full | full |

`skill-create` is **partial** everywhere but Claude Code for one reason: its
eval loop spawns probe sessions of a model that already has the draft skill
installed, and no other harness exposes that primitive. Every other phase —
interview, draft, description optimization, packaging, the `skill-check` gate —
runs unchanged. When the eval loop cannot run, the skill reports the numbers as
unavailable rather than inventing them.

`command-rename` needs an authenticated `gh` and a resolvable git remote on any
harness; it fails fast instead of guessing. Skills that pause for an answer
(`skill-refactor`'s plan confirmation, `ux-guidelines`' target selection,
`command-rename`'s ambiguous-family prompt) need a real user reply; an
auto-approve session setting is not one.

## Layout

Manifests live at the repo root and all point at one flat `skills/` directory:

```
.
├── skills/{skill-create,skill-check,skill-refactor,sh-check,ux-guidelines,command-rename}/
│   ├── SKILL.md
│   └── references/
├── .claude-plugin/{marketplace,plugin}.json     Claude Code
├── .codex-plugin/plugin.json                    Codex
├── .kimi-plugin/plugin.json                     Kimi CLI
├── .hermes-plugin/{plugin.yaml,__init__.py}     Hermes Agent
├── .opencode/plugins/authoring.js + INSTALL.md  OpenCode
├── .agents/plugins/marketplace.json             Antigravity
├── gemini-extension.json + GEMINI.md            Gemini CLI
├── package.json
├── CLAUDE.md · AGENTS.md -> CLAUDE.md
└── LICENSE
```

Only Claude Code understands a nested `plugins/<name>/skills/` layout. The other
five harnesses resolve manifests at the repo root and a skills tree at
`./skills/`, so this repo keeps everything flat. See [`CLAUDE.md`](CLAUDE.md) for
the full rationale and contribution rules.

The `.kimi-plugin/` manifest is pre-provisioned: Kimi CLI is not installed on the
maintainer's machines yet, and shipping the manifest now costs nothing and saves
a migration later.

## CI

[`.github/workflows/validate.yml`](.github/workflows/validate.yml) calls the
reusable workflow owned by
[`dEitY719/harness-skills`](https://github.com/dEitY719/harness-skills/blob/main/.github/workflows/skill-check.yml)
(#1410 D-10) — manifest parsing, required files, skill frontmatter,
progressive-disclosure line limits, the Codex description budget, version
agreement, shellcheck, and an emoji gate.

There are no checks defined in this repo. To change what is validated here, open
a PR against `harness-skills`; a merge to its `main` ships to all fifteen repos
at once.

**The `skill-check` name appears twice, and that is not a cycle.** The reusable
CI workflow is called `skill-check.yml` and one of the six skills is called
`skill-check`. They are different layers: the first is a GitHub Actions job that
parses this repo's manifests on a runner, the second is a `SKILL.md` audit
procedure a model follows against some *other* repo. Neither validates itself
and neither invokes the other. See [`CLAUDE.md`](CLAUDE.md) for the long version.

The emoji gate is passed `allow-emoji-paths: skills/skill-check/references/`.
That skill's Check 11 documents the `ai-metrics` footer exception and its
allowlist file is the data behind it — a policy you cannot read is not a policy.
Nothing else in the repo may carry an emoji.

## Provenance

These skills were extracted from
[`dEitY719/dotfiles`](https://github.com/dEitY719/dotfiles)
(`claude/skills/{skill-create,skill-check,skill-refactor,sh-check,devx-ux-guidelines,devx-command-rename}`)
as a content snapshot — no history rewriting. The source commit SHA is recorded
in this repo's first commit message. The `devx-` prefix is dropped here because
the plugin namespace (`authoring:`) now supplies it; the dotfiles originals stay
put and `/skill:check`, `/sh:check`, `/devx:ux-guidelines`, and
`/devx:command-rename` keep working there until #1410 Phase 4 removes them.

`skills/skill-create/` is itself a vendored copy of Anthropic's marketplace
`skill-creator` plugin, taken deliberately so it survives plugin updates and
since diverged; see `skills/skill-create/references/local-patches.md` and
`skills/skill-create/LICENSE.txt`.

This is part of Phase 2 of the dotfiles #1410 migration; `packaging-skills` was
Phase 0, and `harness-skills`, `notes-skills`, and `visuals-skills` are its
Phase 1 siblings.

## License

MIT. See [LICENSE](LICENSE). `skills/skill-create/` additionally carries its
upstream `LICENSE.txt`.
