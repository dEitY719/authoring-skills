/authoring:skill-refactor — Refactor a SKILL.md to under 100 lines using Progressive Disclosure

Usage:
  /authoring:skill-refactor [path/to/SKILL.md]

Options:

| Option | Description | Default |
|---|---|---|
| `[path]` | SKILL.md to refactor | search for one from the current directory |
| `-h`, `--help`, `help` | Print this message and stop; no files read or written | off |

Examples:
  /authoring:skill-refactor
  /authoring:skill-refactor skills/my-skill/SKILL.md
  /authoring:skill-refactor help

Note: Always presents a refactoring plan and waits for confirmation before writing files.
