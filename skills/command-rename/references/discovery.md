# authoring:command-rename — Discovery checklist (F-2)

Goal: find the family's **definitions** and **every reference point**, so the
mapping designed in Step 5 has no dangling reference left after the eventual
rename. A missed category means a broken alias, stale help text, or a failing
test survives the refactor. Discovery is read-only — never edit.

## Running the sweep

```bash
bash skills/command-rename/lib/discover-refs.sh <family-token> [dotfiles-root]
```

`dotfiles-root` defaults to `$DOTFILES_ROOT`, else `$HOME/dotfiles` — the
`dEitY719/dotfiles` checkout. Run against another repo and the paths below
resolve to nothing.

| | |
|---|---|
| stdout | one row per hit: `category<TAB>file<TAB>line<TAB>text`, file relative to the root |
| exit 0 | hits found |
| exit 1 | no hits — the family token is wrong, or the root is |
| exit 2 | missing `<family-token>`, or the root is not a directory |

Matching treats `_` as a boundary, so `agy` also finds `_agy_run` and
`agy-help` but not `shaggy`.

`bash skills/command-rename/lib/selftest.sh` asserts these contracts.

## What each category means

| Category | What it covers |
|---|---|
| `definition` | `shell-common/tools/integrations/*.sh` and `shell-common/functions/*.sh` — where aliases/functions are declared |
| `inline-help` | help strings and `# DOC:`-style comment blocks naming the command |
| `installer` | `install_*.sh` scripts referencing the alias/binary name |
| `help-registry` | the `my_help.sh` `HELP_DESCRIPTIONS` topic entry |
| `help-adapter` | `zz_help_standard_adapter.sh` wiring |
| `help-test` | `tests/integration/test_help_*.py` assertions |
| `bats` | `tests/bats/**` function/alias tests |

Every category the sweep emits becomes part of the "범위(Scope)" list in the
refactor issue body. The sweep is deliberately generous — it over-reports
rather than miss a category. Reading the rows and deciding which hits are real
reference points (versus incidental prose) is the judgment step; do not skip it
by pasting raw output into the issue.

If a category comes back empty, confirm it is genuinely absent before moving
on — an empty `help-registry` usually means the command was never registered,
which is itself worth noting in the issue.

## git-family exception (always excluded)

`gb`, `gwt`, and other high-frequency git abbreviations are **always**
excluded from rename candidates, regardless of the requested convention.
Muscle-memory git aliases are intentionally short; renaming them breaks daily
workflows for no naming-consistency gain. Drop them from the candidate set in
Step 4 and note the exclusion explicitly in the issue body.
