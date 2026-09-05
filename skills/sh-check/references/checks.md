# authoring:sh-check — 10 Quality Criteria

Each check returns PASS / WARN / FAIL / N/A. The reference implementation
is `$SHELL_COMMON/functions/git_worktree.sh` — when the target file uses
the same pattern, the check passes.

Every `shell-common/...` path below is relative to the `dEitY719/dotfiles`
checkout: `$SHELL_COMMON`, which defaults to `$HOME/dotfiles/shell-common`.
Run against another repo and these paths resolve to nothing.

---

## Structure Checks (1–5)

### Check 1 — Shebang + POSIX Hygiene

**What to look for**
- Line 1 is `#!/bin/sh` (preferred) or `#!/usr/bin/env bash` (bash-only OK)
- POSIX-portable syntax throughout: `[ ]` not `[[ ]]`, `>/dev/null 2>&1`
  not `&>/dev/null`, `local var=""` not `declare`, no `function name()`.
- For `shell-common/` files: must be `#!/bin/sh` (POSIX-only enforced).

| Result | When |
|--------|------|
| PASS | `#!/bin/sh` shebang + POSIX-only syntax detected |
| WARN | Shebang correct but `[[ ]]` or `&>` used in non-bash branch |
| FAIL | Missing shebang, or shell-common file uses bash-only syntax |
| N/A  | File is sourced fragment with no shebang AND lives outside shell-common (rare) |

**Grep hints**
```sh
head -1 "$FILE"                    # shebang
grep -nE '\[\[|&>/dev/null' "$FILE"   # bashisms
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

git_worktree.sh uses 78-char `=`-fences. Any consistent banner counts.

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

git_worktree.sh pattern: `gwt-help [section]` with `--list` / `--all` /
`<section>` arguments, all rendered via `ux_table_row`.

| Result | When |
|--------|------|
| PASS | `-h\|--help` handled, structured help (table or sections), early return |
| WARN | Help exists but is just an inline echo string, not a function |
| FAIL | No help flag — user must read the source |
| N/A  | Function takes no arguments (pure side-effect helper) |

**Grep hints**
```sh
grep -nE -- '-h\|--help|--help)' "$FILE"
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
Status/diagnostic functions emit a structured 2–3 line verdict with an
explicit state value. git_worktree.sh's `_gwt_compute_status` is the
template:

```
state: dirty
age:   2h
next:  gwt push --force-with-lease
```

Or a key:value table via `ux_info "  Key: $value"`.

| Result | When |
|--------|------|
| PASS | Explicit state + structured key:value rows |
| WARN | Output is structured but no canonical "state" field |
| FAIL | Free-form prose verdict ("looks good", "something wrong") |
| N/A  | File defines no status/verdict function |

### Check 10 — Next-action Hint

**What to look for**
Success output ends with a one-line hint pointing at the next command the
user should run. git_worktree.sh's status verdicts include `next: gwt
teardown`, `next: gwt push`, etc.

| Result | When |
|--------|------|
| PASS | Every success path ends with a `Next:` / `next:` hint or `ux_bullet`'d command |
| WARN | Some hints, but not consistently |
| FAIL | No next-action guidance anywhere |
| N/A  | Terminal command — there is no logical "next" step |

**Grep hints**
```sh
grep -nE -- 'Next:|next:|next-action' "$FILE"
```

---

## Scoring

After running all 10 checks, compute:

- `PASS_COUNT` — number of PASS results
- `WARN_COUNT` — number of WARN results
- `FAIL_COUNT` — number of FAIL results
- `NA_COUNT`   — number of N/A results

`Score: PASS_COUNT/(10 - NA_COUNT) checks passed (WARN_COUNT warnings)`

The Verdict line is computed in `references/report-template.md`.
