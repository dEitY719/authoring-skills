# Batch Mode — what gets audited

SSOT for the input modes, skill-name resolution, discovery, snapshot auditing
and the temporary-directory rules. The executable half is
`lib/skill_scan.sh` (its header is the I/O contract); issue targets and
filing are in `references/issue-filing.md`.

## Input modes (mutually exclusive)

| Mode | Argument | Audits |
|---|---|---|
| single | `<path>` or `<skill-name>` (none: search from the cwd) | one SKILL.md |
| dir | `-d, --dir <dir>` | every SKILL.md under `<dir>` |
| repo | `-r, --repo <git-url>` | `git clone --depth 1` into a temp dir, then as dir; deleted afterwards |
| recursive | `-R, --recursive <root>` | each git repo (`<d>/.git` exists) **directly** under `<root>`, each as dir |

`skill_scan.sh args` validates the arguments. Exit 2, with a message, for: more
than one of `<path>`/`-d`/`-r`/`-R`; `--issue` with `--no-issue`; `-d`/`-r`/`-R`
without a value; a `-r` value that is not a git URL; and the pre-rename
`<path> --recursive` form, which names `--deep-subskills` as the new spelling
of the Check 13 Sub-skill Model Plan depth.

## Skill-name resolution (`skill_scan.sh resolve`)

A leading `/` is dropped; `plugin:skill` and bare `skill` are accepted. The
first step that matches wins:

1. An existing file is used as is; a directory means `<dir>/SKILL.md`.
2. Local checkouts — the cwd's git toplevel and each git repo directly under
   the cwd, main checkouts before linked worktrees. Use
   `skills/<skill>/SKILL.md` from the repo whose `.claude-plugin/plugin.json`
   `name` equals `plugin`. Local copies come first: an issue needs a remote,
   and a plugin cache can be stale.
3. `installed_plugins.json` (`$CLAUDE_CONFIG_DIR`, then `~/.claude*/plugins/`):
   `<installPath>/skills/<skill>/SKILL.md` of the `<plugin>@…` entry.
4. Bare names only: the flat link `~/.claude*/skills/<skill>/SKILL.md`.
5. A bare `skill` that matches skills of two or more different plugins within
   one step is ambiguous: every candidate is printed and the exit is 2. The
   resolver never picks one arbitrarily.

## Discovery inside a repo

`find -L <dir> -maxdepth 4 -name SKILL.md`, pruning `.git`, `node_modules`,
`.claude` (worktrees included), `.worktrees`, `tests`, `fixtures` and `vendor`;
de-duplicated by physical path. In a marketplace repo that leaves
`skills/*/SKILL.md`.

## Snapshot auditing

**A run that files issues audits the issue target's default-branch snapshot.
A run that does not (`--no-issue`, single mode by default) audits the working
tree.** A local checkout may sit on a feature branch or be dirty: auditing it
would file findings that the target's default branch does not have, or has
already fixed. It is also a leak guard — the target may be public, and an
issue body must quote only what that repo already publishes.

`skill_scan.sh scan ... --snapshot` does, per repo:

1. `git fetch <target-remote>` (read-only).
2. Default branch from `refs/remotes/<target-remote>/HEAD`, else
   `git ls-remote --symref <target-remote> HEAD`, else
   `gh repo view --json defaultBranchRef`.
3. Check out that commit into the temp dir through a private index
   (`read-tree` + `checkout-index`, so `export-ignore` cannot drop files); that
   copy is what gets audited (`snapshot_ref` = `<remote>/<branch>@<sha>`). An
   empty `.git` directory marks its root, so walk-ups stop there.
4. A failed fetch falls back to the existing remote-tracking ref and appends
   `stale:<commit date>` to `snapshot_ref`; show it as a warning in the Issue
   Plan. No ref at all: a `skip` row for that repo.

`-r` needs none of this: the shallow clone is the default-branch snapshot.
When the URL is a fork, `--snapshot` clones the fork parent instead (the issue
target, `references/issue-filing.md`), never the fork.
A repo with no usable remote has no issue target, so it is audited from the
working tree and its issue is reported `[SKIP] no remote`.

## Running it

```sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/skill-check.XXXXXX") && echo "$tmp"
sh <skill-dir>/lib/skill_scan.sh scan <mode> <target> --tmp "$tmp" [--snapshot]
```

Pass `--snapshot` exactly when issue filing is on.
Each output row is `repo_dir skill_md target_host target_repo target_source
snapshot_ref`; a row whose `skill_md` is `-` is a status row (`dup`/`skip`,
reason in the last column) to show in the Batch Summary, not a skill to audit.

**Temporary directory.** Clones and snapshots live only under that one
`mktemp` directory. When the run ends, delete it with a standalone command on
its literal path — `rm -rf /tmp/skill-check.AbC123` — never inside `sh -c`,
`eval` or `$(...)`, where an unattended session cannot approve it. An empty
path is never deleted.

## Scale: one subagent per repo

`-R` can mean ~100 skills across ~20 repos — too much for one context. Where
the harness has subagents, run **one subagent per repo in parallel** at this
skill's `model_recommendation` tier (sonnet). Each runs Step 2 for its repo's
rows and returns, per skill, only the compressed result: the 19 result rows,
the score row, and the Problem/How-to-fix detail of each WARN/FAIL (with the
quoted SKILL.md lines). Without subagents, process the repos one by one.

Subagents never file issues. The main session collects every result, prints
the Batch Summary and Issue Plan, asks the one confirmation, and files — so
dedup and sequential creation happen in exactly one place.
