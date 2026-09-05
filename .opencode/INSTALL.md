# Installing authoring for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed

## Installation

Add the plugin to the `plugin` array in your `opencode.json` (global or
project-level):

```json
{
  "plugin": ["authoring-skills@git+https://github.com/dEitY719/authoring-skills.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers all six skills.

OpenCode uses its own plugin install. If you also use Claude Code, Codex, or
another harness, install this plugin separately for each one.

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load skill-check
```

## Tool mapping

The authoritative OpenCode tool mapping for every `dEitY719/*-skills` repo is
owned by the sibling repo
[`dEitY719/harness-skills`](https://github.com/dEitY719/harness-skills/blob/main/references/opencode-tools.md)
(dEitY719/dotfiles#1410 F-5). Read it there when a skill names a tool you do not
recognise; this repo keeps no copy on purpose. Short version:

- "Read a file" -> `read`
- "Create a file" / "edit a file" -> `apply_patch`
- "Run a shell command" -> `bash`
- "Search file contents" / "find files by name" -> `grep`, `glob`
- "Create a todo" -> `todowrite`
- "Ask the user" -> OpenCode has no dedicated ask tool; stop and ask in your
  reply, then wait. `skill-refactor` (plan confirmation), `ux-guidelines`
  (target selection), and `command-rename` (ambiguous command family) all need
  a real answer.
- "Invoke a skill" -> OpenCode's native `skill` tool

`skill-create` ships Python helpers under `skills/skill-create/scripts/` and
`eval-viewer/`; run them through `bash`. Its eval loop needs a way to spawn a
model session that already has the draft skill installed — OpenCode has no such
primitive, so run the phases that work and report the eval numbers as
unavailable rather than inventing them.

`command-rename` shells out to `gh`. Without an authenticated `gh` and a
resolvable remote it fails fast; that is intended.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i authoring`
2. Verify the plugin line in your `opencode.json`
3. Make sure you are running a recent version of OpenCode

### Skills not found

1. Use the `skill` tool to list what was discovered
2. Check that the plugin is loading (see above)

## Getting Help

Report issues: https://github.com/dEitY719/authoring-skills/issues
