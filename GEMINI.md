# authoring — skill index

Six skills for the source material an AI harness reads: skill files, shell
scripts, help text, command names. Each lives in this extension's `skills/`
directory. They are task-triggered: load the one that matches the job by
reading its `SKILL.md`, then follow it. Do not load all six.

| Skill | Read | Use when |
|-------|------|----------|
| `skill-create` | `@./skills/skill-create/SKILL.md` | Building a new skill from an idea, or improving and evaluating an existing one — interview, draft, eval loop, description tuning, packaging. |
| `skill-check` | `@./skills/skill-check/SKILL.md` | Auditing one `SKILL.md` against 16 structure, UX, model, security, and context-budget checks. Read-only. |
| `skill-refactor` | `@./skills/skill-refactor/SKILL.md` | A `SKILL.md` is over 100 lines and its detail needs extracting into `references/`. |
| `sh-check` | `@./skills/sh-check/SKILL.md` | Auditing a `*.sh` file against 10 shell quality criteria. Read-only. |
| `ux-guidelines` | `@./skills/ux-guidelines/SKILL.md` | Shell help text uses raw `echo`/`printf`/ANSI and should use semantic `ux_lib` calls instead. |
| `command-rename` | `@./skills/command-rename/SKILL.md` | Designing a command-naming refactor and filing the tracking issue — the rename itself runs later. |

Each skill's `references/` directory holds the detail it loads on demand;
`SKILL.md` says which file to read and when. Do not read `references/` files up
front.

## Picking between them

The discriminator is **what artifact you are pointing at** and **whether the
skill may write**:

- A `SKILL.md`: `skill-check` audits it, `skill-refactor` rewrites it,
  `skill-create` produces it. Run `skill-check` first; it tells you whether
  `skill-refactor` is needed.
- A `*.sh` file: `sh-check` audits its structure and UX;
  `ux-guidelines` rewrites its user-facing output.
- A command or alias name: `command-rename` — and it files an issue rather than
  performing the rename.
- An `AGENTS.md` / `CLAUDE.md` / `GEMINI.md`: none of these. That is
  `harness:ai-context` in the sibling `dEitY719/harness-skills` repo.

Read-only: `skill-check`, `sh-check`, `command-rename` (it writes GitHub issues,
never files). Write: `skill-create`, `skill-refactor`, `ux-guidelines`.

## Tool mapping for Gemini CLI

The skills speak in actions. On Gemini CLI these resolve to:

- "Read a file" -> `read_file` / `read_many_files`
- "Create a file" / "edit a file" -> `write_file`, `replace`
- "Run a shell command" -> `run_shell_command`
- "Search file contents" -> `grep_search`
- "Find files by name" -> `glob`
- "Create a todo" -> `write_todos`
- "Ask the user" -> `ask_user`
- "Dispatch a subagent" -> `invoke_agent` with `agent_name: "generalist"`

The full mapping, including every capability gap and its workaround, is owned by
the sibling repo `dEitY719/harness-skills` at `references/gemini-tools.md`
(dEitY719/dotfiles#1410 F-5) — read it there; this repo keeps no copy. On Antigravity
read that repo's `references/antigravity-tools.md` instead: `agy` shares
`~/.gemini` but not Gemini CLI's tool names.

## Capability gaps on Gemini CLI

- `skill-create`'s eval loop spawns probe sessions of a model that already has
  the draft skill installed. Gemini CLI cannot do that natively: run the phases
  it can (interview, draft, description tuning, packaging), and say plainly that
  the eval numbers are unavailable rather than inventing scores.
- `skill-create` also ships Python helpers under `scripts/` and `eval-viewer/`.
  Run them with `run_shell_command`; do not re-implement them in prose.
- `command-rename` files GitHub issues through `gh` via `run_shell_command`. It
  needs an authenticated `gh` and a resolvable git remote, and it fails fast
  rather than guessing either.
- `ux-guidelines` targets a repo that already provides `ux_lib`. Outside such a
  repo it has nothing to refactor toward — say so instead of inventing helper
  names.

## Safety rules

- **Audits never write.** `skill-check` and `sh-check` are read-only and report
  every criterion, including the ones that pass. Never stop at the first FAIL,
  and never "fix while auditing".
- **Rewrites confirm first.** `skill-refactor` presents its extraction plan and
  waits for a yes before touching files. `ux-guidelines` does the same for a
  bulk sweep.
- **`command-rename` renames nothing.** It produces one `refactor` issue (plus a
  `docs` issue when the convention is not codified) and stops. Executing the
  rename is a separate, later run of `/gh-flow:issue`.
- **Never fabricate a verdict.** A check you could not run is `N/A` with the
  reason, not a PASS.
