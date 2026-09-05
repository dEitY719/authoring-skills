/authoring:skill-refactor — Refactor a SKILL.md to under 100 lines using Progressive Disclosure

Usage:
  /authoring:skill-refactor [path/to/SKILL.md]

Arguments:
  [path]    Path to the SKILL.md file to refactor (optional)
            If omitted, searches for SKILL.md from the current directory

Examples:
  /authoring:skill-refactor
  /authoring:skill-refactor skills/my-skill/SKILL.md
  /authoring:skill-refactor help

Options:
  -h, --help, help   Show this message and stop. No files are read or written.

Note: Always presents a refactoring plan and waits for confirmation before writing files.
