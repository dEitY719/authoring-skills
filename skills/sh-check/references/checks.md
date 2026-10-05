# authoring:sh-check — 10 Quality Criteria

Each check returns PASS / WARN / FAIL / N/A. The concrete pattern quoted in
each entry below is the bar — nothing here requires a file outside the
repository being audited.

Checks 1, 2, 4, 5, 6, 7, 9 and 10 are decided mechanically by
`lib/sh_check.sh`; the entries below document what it looks for, so a rule
change lands in both. The other two (3 Section Anatomy, 8 Input Validation) are
the auditor's judgment.

Checks 9 and 10 are written against one reference implementation: gwt's
`_gwt_compute_status` (`dEitY719/dotfiles`
`shell-common/functions/git_worktree.sh`), whose contract `_gh_flow_verdict`
in `gh_flow.sh` shares.

`shell-common/` names a shared cross-shell tree (the layout these rules came
from, `dEitY719/dotfiles`). A repo without one simply never trips the
`shell-common`-only arms.

---

## Structure Checks (1–5)

### Check 1 — Shebang + POSIX Hygiene

**What to look for**
- Line 1 is `#!/bin/sh` (preferred) or `#!/usr/bin/env bash` (bash-only OK)
- POSIX-portable syntax throughout: `[ ]` not `[[ ]]`, `>/dev/null 2>&1`
  not `&>/dev/null`, `local var=""` not `declare`, no `function name()`.
- For `shell-common/` files: must be `#!/bin/sh` (POSIX-only enforced).
- Exception: a top-level `shell-common/tools/custom/*.sh` is an executed bash
  entrypoint and must be exactly `#!/bin/bash` (`#!/bin/sh` there is FAIL —
  the dotfiles shebang hook rejects it). Subdirectories such as
  `tools/custom/lib/*.sh` are source-only and keep `#!/bin/sh`. SSOT: dotfiles
  `git/config/hook-config.sh` (`DOTFILES_HOOKS_SHEBANG_SHELL_COMMON_CUSTOM`),
  classified by `custom_tool_class` in `git/hooks/checks/shared.sh`.

| Result | When |
|--------|------|
| PASS | `#!/bin/sh` shebang + POSIX-only syntax detected, or a `tools/custom/*.sh` entrypoint with `#!/bin/bash` |
| WARN | Shebang correct but `[[ ]]` or `&>` used in non-bash branch |
| FAIL | Missing shebang, shell-common file uses bash-only syntax, or a `tools/custom/*.sh` entrypoint is not `#!/bin/bash` |
| N/A  | File is sourced fragment with no shebang AND lives outside shell-common (rare) |

**Grep hints**
```sh
head -1 "$FILE"                    # shebang
sed -E 's/\\\[//g; s/\[:[[:alpha:]]+:\]//g' "$FILE" | grep -nE '\[\[|&>'   # bashisms; drops escaped \[ (regex literals) and POSIX classes like [[:space:]] first
```

### Check 2 — Interactive Guard

**What to look for**
Sourced files (anything under `shell-common/functions/`, `bash/`, `zsh/`,
or any file whose first few lines call `local`/`alias` without an `exec`
context) must start with:

```sh
case $- in *i*) ;; *) [ -n "${DOTFILES_FORCE_INIT-}" ] || return 0 ;; esac
```

| Result | When |
|--------|------|
| PASS | Guard present in the first ~10 lines of a sourced file |
| WARN | Guard present but later in the file (after function defs) |
| FAIL | Sourced file with no interactive guard |
| N/A  | File is an executable script (has `#!` and is `chmod +x`'d) |

**Grep hints**
```sh
head -20 "$FILE" | grep -F 'case $- in *i*'
```

### Check 3 — Section Anatomy

**What to look for**
Each public function is preceded by a `# ===…===` header block containing
at minimum a one-line description. Substantial functions also have:
- `# Usage: <name> <args>`
- `# Args:` with one line per argument

A 78-char `=`-fence is the original form. Any consistent banner counts.

| Result | When |
|--------|------|
| PASS | Banner + Usage/Args on most public functions |
| WARN | Banners present but Usage/Args missing |
| FAIL | No section structure — functions defined back-to-back |
| N/A  | Single-function file under 30 lines |

**Grep hints**
```sh
grep -cE '^# ={5,}' "$FILE"           # banner count
grep -cE '^# Usage:'   "$FILE"
```

### Check 4 — Naming Convention

**What to look for**
- Private helpers use `_prefix_` (e.g. `_gwt_age`, `_gh_pr_edit_safe_label`)
- Public functions are non-underscored (`gwt`, `gwt_help`, `gh_pr_status`)
- All names in `snake_case` — no `camelCase`, no `kebab-case` for functions
- User-facing aliases may use `dash-form` (e.g. `gwt-help`)

| Result | When |
|--------|------|
| PASS | Consistent _private vs public, all snake_case |
| WARN | Mostly consistent but 1–2 outliers |
| FAIL | No discernible convention, or camelCase used |
| N/A  | File defines no functions (pure config / sourced env file) |

**Grep hints**
```sh
grep -E '^[A-Za-z_][A-Za-z0-9_]*\(\) *\{' "$FILE" \
  | sed 's/().*//' | sort -u
```

### Check 5 — ZSH Compat Guard

**What to look for**
Any function exposed to *both* bash and zsh (i.e. defined in
`shell-common/`) and that uses `local`, arrays, or `set -x` must contain:

```sh
[ -n "${ZSH_VERSION-}" ] && emulate -L sh
```

…near the top of the function. This avoids the zsh-tracing-of-`local`
issue documented in MEMORY.md.

| Result | When |
|--------|------|
| PASS | All cross-shell functions have the guard |
| WARN | Some functions have it, others don't |
| FAIL | File is in `shell-common/` and no function has the guard |
| N/A  | File is bash-only (lives in `bash/`) or zsh-only (`zsh/`), or is an executable script |

**Grep hints**
```sh
grep -nE 'emulate -L sh|ZSH_VERSION' "$FILE"
```

---

## UX Quality Checks (6–10)

### Check 6 — Help Flag

**What to look for**
Every public command-style function handles `-h|--help` and delegates to a
structured help routine, then `return 0` (or `exit 0` for executables).

Canonical form: `<cmd>-help [section]` with `--list` / `--all` / `<section>`
arguments, all rendered via `ux_table_row`.

| Result | When |
|--------|------|
| PASS | `-h\|--help` handled, structured help (table or sections), early return |
| WARN | Help exists but is just an inline echo string, not a function |
| FAIL | No help flag — user must read the source |
| N/A  | Function takes no arguments (pure side-effect helper) |

Mechanically, PASS needs the flag in an option position — a case pattern or a
test, not prose in a comment — *and* a `*help` function with a call site, so a
defined-but-unwired help routine does not carry the file. Whether every public
command routes to it is the auditor's call.

**Grep hints**
```sh
grep -nE -- '(-h|--help)[^[:alnum:]]*[])|]' "$FILE"   # flag in option position
```

### Check 7 — UX Lib Usage

**What to look for**
Output goes through `ux_header`, `ux_section`, `ux_info`, `ux_success`,
`ux_warn`, `ux_error`, `ux_bullet`, `ux_table_row`. **No raw `echo`,
`printf`, or `tput`** in user-facing paths.

Exceptions allowed: stdout used for return values (e.g.
`printf '%s\n' "$result"` from a helper that's captured by `$()`), debug
output behind `[ "${DEBUG:-0}" = "1" ]`.

| Result | When |
|--------|------|
| PASS | All user-facing output via ux_* functions |
| WARN | Mix — some ux_*, some raw echo for messages |
| FAIL | Pure raw `echo`/`tput`, no ux_lib import or usage |
| N/A  | File defines no user-facing output (e.g. pure data helper) |

**Grep hints**
```sh
grep -cE 'ux_' "$FILE"
grep -cE '(echo|printf|tput) ' "$FILE"
```

### Check 8 — Input Validation

**What to look for**
- Required arguments checked: `[ -z "$1" ] && { ux_error …; return 1; }`
- Mutually exclusive flags rejected explicitly
- Unknown options trigger help + non-zero exit:
  `*) ux_error "Unknown option: $1"; gwt-help; return 1 ;;`

| Result | When |
|--------|------|
| PASS | Required args, mutex flags, unknown-option arm all present |
| WARN | Some validation but missing one of the three |
| FAIL | No validation — function silently does the wrong thing |
| N/A  | Function takes no arguments |

**Grep hints**
```sh
grep -nE 'Unknown option|Missing argument|Required' "$FILE"
```

### Check 9 — Verdict Output

**What to look for**
A status/diagnostic function (name contains `status` or `verdict`) computes a
fixed-line verdict and hands rendering to a separate caller. The gwt contract,
excerpted verbatim from `dEitY719/dotfiles@89c2763`
`shell-common/functions/git_worktree.sh`:

```sh
# Output (3 lines):
#   <state>        — one of: prunable|locked|dirty|pr-open|pr-merged|
#                     pr-closed|merged|ahead|stale|clean
#   <age>          — short human-readable, e.g. "5m"/"2h"/"5d"/"3w"/"-"
#   <next-action>  — single-line hint, e.g. "gwt teardown"
#
# Priority order matches issue #285 §A:
#   prunable > locked > dirty > pr-state > merged > ahead > stale > clean
_gwt_compute_status() {
    ...
    case "$_pr_state" in
        OPEN)
            printf '%s\n%s\n%s\n' "pr-open" "$_age" "gh pr view ${_pr_num}"
    ...
    printf '%s\n%s\n%s\n' "ahead" "$_age" "git push -u origin ${_branch}"
    ...
    printf '%s\n%s\n%s\n' "clean" "$_age" "-"
}

# caller (_gwt_emit_row) renders one PATH/BRANCH/STATE/AGE/NEXT table row
_verdict_out=$(_gwt_compute_status "$_path" "$_branch" "$_is_main" \
                                    "$_pr_state" "$_pr_num")
```

PASS conditions — each one is a signal `lib/sh_check.sh` greps for:

1. **Fixed lines** — the verdict is returned as `printf '%s\n%s\n%s\n'`
   (state / age / next), never as prose.
2. **Fixed state vocabulary** — a `case "$_state" in` (or `$..status` /
   `$..verdict`) switches on a closed set of state words.
3. **Compute / render split** — the computing function is called through
   `$(...)` by another function that renders it; it never prints the row itself.
4. **Documented first-match priority** — a comment orders the states as
   `a > b > c`, so the first matching state wins and the order is reviewable.
5. **Network is opt-in** — the default verdict uses local signals only; a
   network-backed state (PR state) is computed only behind an explicit flag
   such as gwt's `--remote`. The helper flags a `gh`/`curl`/`wget` call in
   command position inside a fixed-line verdict function unless the call line,
   an enclosing `if`/`elif`, or its `case` arm names an opt-in token
   (`remote|network|online`); the `else` of such a branch is not gated. A
   `"gh pr view 1"` NEXT string, `command -v gh` and comments are not calls.
   gwt passes as-is: `_gwt_compute_status` takes the PR state as an argument
   and its own `gh` calls live in `_gwt_remote_pr_states`, which the caller
   runs only under `--remote` (issue #42).

The opt-in test is a name match on the condition, not data flow: a call gated
on an unconventionally named flag lands in WARN, never FAIL — widen `opt_in`
in `lib/sh_check.sh` when a real flag name keeps landing there.

| Result | When |
|--------|------|
| PASS | All five signals present |
| WARN | Fixed-line return (2 or 3 lines), but a signal is missing — the note lists which (e.g. `missing: state case`, `missing: network opt-in (<fn>)`) |
| FAIL | A status/verdict function with no fixed-line return — a free-form prose verdict ("looks good") |
| N/A  | File defines no status/verdict function |

### Check 10 — Next-action Hint

**What to look for**
The NEXT value of every verdict — the last argument of each fixed-line
`printf '%s\n%s\n...'` — is a command the user can copy and run. A `"$var"`
there is resolved through that variable's non-empty `var="..."` assignments.

Command-shaped means one of:

- a known command prefix: `gwt `, `git `, `gh `, `ps `, or a hyphenated member of that family (`gh-flow `, #41);
- a skill invocation: `/plugin:skill`;
- `-` — the terminal-state marker;
- any of the above behind `cd <arg> && ` (`cd $_wt && gwt teardown`, #47) — the part after `&&` is judged by the same rule, so `cd X && review it` stays WARN.

Prose that merely contains a command (`review 'x', then gh-flow prune 1`, `inspect $_dir`) stays WARN by design.

**Terminal states use `-`, never a blank.** A state with no logical next step
(gwt's `clean`) returns `-` so the column stays aligned and the reader can tell
"nothing to do" from "forgot to say".

| Result | When |
|--------|------|
| PASS | Every NEXT value is command-shaped |
| WARN | A NEXT value is prose (`commit or stash`), blank, an unknown command, or a variable with no literal assignment — command shape cannot be confirmed |
| FAIL | A status/verdict function returns no NEXT value at all |
| N/A  | File defines no status/verdict function (same rule as Check 9) |

Command shape is a prefix heuristic, so anything it cannot confirm is WARN,
never FAIL: a false FAIL would mark down the reference implementation itself. gwt
itself scores WARN here — its `dirty` NEXT is `commit or stash`, which
`lib/sh_check.sh` reports as `1 of 11 NEXT value(s) not a command`.

### Per-function verdict table (checks 9 and 10)

A file score buries one status function among dozens — gwt is 2627 lines and
54 functions. So `lib/sh_check.sh` also prints, before the `score` row, one
`fn<TAB>function<TAB>vocab<TAB>next-ok/next-n<TAB>result` row per function
that returns a fixed-line `printf '%s\n%s\n...'` verdict, using the same
function boundaries as Check 5:

- **vocab** — distinct literal states (the first printf argument); `?` when a
  state is not a literal (`"$_state"`).
- **next** — command-shaped NEXT values over all NEXT values, judged as in
  Check 10.
- **result** — FAIL when no NEXT is found, WARN on a `?` vocab or any
  unconfirmed NEXT, else PASS.

gwt prints `fn  _gwt_compute_status  10  10/11  WARN`. A file with no such
function prints no `fn` rows. The table is informational; checks 9 and 10 and
the score are computed as above.

---

## Scoring

After running all 10 checks, compute:

- `PASS_COUNT` — number of PASS results
- `WARN_COUNT` — number of WARN results
- `FAIL_COUNT` — number of FAIL results
- `NA_COUNT`   — number of N/A results

`Score: PASS_COUNT/(10 - NA_COUNT) checks passed (WARN_COUNT warnings)`

`lib/sh_check.sh` emits this arithmetic and the verdict as its final `score`
row once it is given the two judgment results; the table it implements lives
in `references/report-template.md`.
