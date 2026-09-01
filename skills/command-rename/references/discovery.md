# authoring:command-rename — Discovery checklist (F-2)

Goal: find the family's **definitions** and **every reference point**, so the
mapping designed in Step 5 has no dangling reference left after the eventual
rename. A missed category means a broken alias, stale help text, or a failing
test survives the refactor. Search read-only (`grep`/`Read`) — never edit.

## 1. Definitions

Where aliases/functions are declared:

- `shell-common/tools/integrations/*.sh` — tool integration alias/function definitions.
- `shell-common/functions/*.sh` — shared function definitions.

Grep the family token across both trees (e.g. `grep -rn '\bagy\b' shell-common/tools/integrations shell-common/functions`).

## 2. Reference points (all categories — check every one)

- **Inline help text / comment DOC blocks** — help strings and `# DOC:`-style comment blocks that name the command.
- **`install_*.sh` scripts** — installers referencing the alias/binary name.
- **`my_help.sh` `HELP_DESCRIPTIONS` registration** — the help-topic registry entry.
- **`zz_help_standard_adapter.sh`** — the standard help adapter wiring.
- **`tests/integration/test_help_*.py`** — pytest help-topic assertions.
- **`tests/bats/**`** — bats function/alias tests.

For each category, grep the old name(s) from the Step 5 mapping and record
every file:line hit — these become the "범위(Scope)" list in the refactor
issue body.

## 3. git-family exception (always excluded)

`gb`, `gwt`, and other high-frequency git abbreviations are **always**
excluded from rename candidates, regardless of the requested convention.
Muscle-memory git aliases are intentionally short; renaming them breaks daily
workflows for no naming-consistency gain. Drop them from the candidate set in
Step 4 and note the exclusion explicitly in the issue body.
