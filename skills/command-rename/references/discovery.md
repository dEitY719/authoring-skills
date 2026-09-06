# authoring:command-rename — Discovery checklist (F-2)

Goal: find the family's **definitions** and **every reference point**, so the
mapping designed in Step 5 has no dangling reference left after the eventual
rename. A missed category means a broken alias, stale help text, or a failing
test survives the refactor. Discovery is read-only — never edit.

## Running the sweep

```bash
sh "${SKILL_DIR}/lib/discover-refs.sh" <family-token> [dotfiles-root]
```

The sweep is **dotfiles-scoped by design**: every category below is defined by
a path or filename (`shell-common/…`, `install_*.sh`, `my_help.sh`,
`zz_help_standard_adapter.sh`, `tests/bats/`) that exists only in the
`dEitY719/dotfiles` checkout, so `dotfiles-root` defaults to `$DOTFILES_ROOT`,
else `$HOME/dotfiles`. SKILL.md Step 1's `TARGET_REPO` is an `owner/repo` slug
naming where the *issue* gets filed — it is not a filesystem path, and is never
used as this sweep's root. To scan a checkout kept somewhere else, pass its
path as the optional second argument; against a repo with a different layout
the categories below simply resolve to nothing.

| | |
|---|---|
| stdout | one row per hit: `category<TAB>file<TAB>line<TAB>text`, file relative to the root |
| exit 0 | hits found |
| exit 1 | no hits — every category ran cleanly and came back empty; usually a wrong family token, or a root whose layout has none of the categories |
| exit 2 | missing `<family-token>`, or the root is not a directory |
| exit 3 | `grep` itself failed — its stderr is reproduced |

The sweep needs a `grep` with `-r` and `--include` (GNU/BSD extensions, not
POSIX). It tells grep's three outcomes apart — hits, no match, grep failed —
so a `grep` that cannot scope by path aborts at exit 3 instead of returning
zero rows for a category and letting the run read as an honest "no hits".

Matching treats `_` as a boundary, so `agy` also finds `_agy_run` and
`agy-help` but not `shaggy` — see "Deliberate over-reporting" below for the
cost that buys.

`sh "${SKILL_DIR}/lib/selftest.sh"` asserts these contracts; `tests/` runs it
in CI. `SKILL_DIR` is this skill's own directory — the helpers do not live in
the repo being swept.

`<family-token>` must match `[A-Za-z0-9_-]+`; anything else exits 2 rather than
being interpolated into the search regex.

## What each category means

| Category | What it covers |
|---|---|
| `definition` | `shell-common/tools/integrations/*.sh` and `shell-common/functions/*.sh` — where aliases/functions are declared |
| `inline-help` | a `*.sh`/`*.zsh`/`*.bash` line naming the command whose text also mentions `DOC:`, help, or usage |
| `reference` | any other `*.sh`/`*.zsh`/`*.bash` line naming the command — ordinary descriptions, call sites, comments |
| `installer` | `install_*.sh` scripts referencing the alias/binary name |
| `help-registry` | the `my_help.sh` `HELP_DESCRIPTIONS` topic entry |
| `help-adapter` | `zz_help_standard_adapter.sh` wiring |
| `help-test` | `tests/integration/test_help_*.py` assertions |
| `bats` | `tests/bats/**` function/alias tests |

`inline-help` and `reference` come from one unfiltered shell sweep: **every**
matching `*.sh`/`*.zsh`/`*.bash` line is emitted, and the DOC/help/usage test
only decides which of the two labels it carries. Nothing is dropped, so the
"ALL reference points" guarantee holds for an ordinary command description that
never says "help".

Every category the sweep emits becomes part of the "범위(Scope)" list in the
refactor issue body. Reading the rows and deciding which hits are real
reference points (versus incidental prose) is the judgment step; do not skip it
by pasting raw output into the issue.

## Deliberate over-reporting

The sweep is generous on purpose: a missed reference point survives the
refactor as a broken alias or stale help text, while an extra row costs one
glance from the human reading the output. Two known, **accepted** false
positives follow from that trade — neither is a bug:

- **`_` counts as a word boundary.** That is exactly what makes `_agy_run`, a
  real definition site, hit. The cost is that an unrelated `unrelated_agy_bar`
  hits too. Narrowing the boundary class to exclude `_` would drop `_agy_run`
  and break the guarantee above, so it stays.
- **One line can appear under several categories.** A definition inside
  `shell-common/` is also a `reference`; `my_help.sh` rows arrive as both
  `help-registry` and `inline-help`. Dedupe when you build the Scope list.

If a category comes back empty, confirm it is genuinely absent before moving
on — an empty `help-registry` usually means the command was never registered,
which is itself worth noting in the issue.

## git-family exception (always excluded)

`gb`, `gwt`, and other high-frequency git abbreviations are **always**
excluded from rename candidates, regardless of the requested convention.
Muscle-memory git aliases are intentionally short; renaming them breaks daily
workflows for no naming-consistency gain. Drop them from the candidate set in
Step 4 and note the exclusion explicitly in the issue body.
