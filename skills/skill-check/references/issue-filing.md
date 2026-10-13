# Issue Filing — where findings go

SSOT for Step 4. Issue filing is on by default in batch modes (`-d`/`-r`/`-R`)
and off in single mode (`--issue` opts in). `--no-issue` turns it off: no
Issue Plan, no issue, working-tree audit. The executable half is
`lib/file_issue.sh` (its header is the I/O contract).

## Issue target: upstream first

For a local repo (`-d`, `-R`, single `--issue`) `skill_scan.sh` resolves:

1. `git remote get-url upstream` exists and parses → **upstream**.
2. Otherwise `origin`.
3. Neither, or the SKILL.md is not in a git checkout (a plugin cache) → no
   issue: report `[SKIP] no remote`.

For `-r <url>` the target is that URL's repo, unless `gh repo view --json
parent` reports a fork parent: a fresh clone has no upstream remote, so the
fork parent stands in for it (`target_source` = `fork-parent`). A manual mirror
(for example a GHES repo copied to github.com) is not a fork, so
`-r <ghes-url>` files on the GHES repo itself; to reach the real upstream, run
`-d` on a local checkout that has an `upstream` remote.

URLs parse as `git@host:o/r(.git)`, `ssh://git@host/o/r` and
`https://host/o/r(.git)`. Every `gh` call carries `GH_HOST=<host>` and
`-R <owner>/<repo>`: when github.com and a GHES host are both logged in, an
unpinned call silently lands on the wrong server.

**Preflight**, once per target: `sh <skill-dir>/lib/file_issue.sh --preflight
<host> <owner/repo>`. `SKIP <reason>` (not logged in, issues disabled, repo
unreachable) skips only that repo's issues; the audit continues.

**One target, one pass.** `-R` folds directories with the same target: a
second checkout (e.g. `jira-skills-claude-1/` beside `jira-skills/`) is a
`dup` row, reported `[DUP] same target as jira-skills/` and not audited, so it
cannot file a duplicate issue.

This skill never runs `git push`. Creating an issue is a `gh` API call.

## Policy

- **When:** a skill with at least one FAIL or WARN. PASS/N/A only → no issue.
- **Unit:** one issue per skill, bundling all of its FAIL/WARN rows.
- **Title:** `fix(<skill>): skill-check findings — <F> FAIL, <W> WARN` when
  any FAIL; `refactor(<skill>): …` when WARN only.
- **Labels:** `fix` or `refactor`, plus `skill` — applied only when the label
  already exists on the target repo. Never create a label on someone's repo.
- **Body:** `references/issue-template.md`, written to a file inside the run's
  temp dir. Its last line is the dedup key.
- **Dedup key:** `skill-check-key: <plugin>:<skill>` from
  `sh <skill-dir>/lib/skill_scan.sh key <SKILL.md>` — the Check 11 key rule;
  bare `<skill>` without a manifest. Only **open** issues count: a fixed and
  closed finding that comes back gets a new issue.

## Issue Plan and the confirmation gate

After every audit has finished, decide each row's status, then print the
Issue Plan (`references/report-template.md`):

| Status | Meaning |
|---|---|
| `NEW` | `file_issue.sh --check <host> <owner/repo> <key>` printed `NEW` |
| `EXISTS #N` | an open issue already carries the key |
| `SKIP <reason>` | no remote, preflight failed, or no FAIL/WARN |
| `DUP` | same target as an earlier directory (`-R`) |

Then ask **once** for confirmation — `AskUserQuestion` where the harness has
it, otherwise ask in text and stop until the user answers. `-y`/`--yes` skips
the question (unattended runs). Nothing is filed before that answer.

## Creating

One issue at a time, in plan order — parallel creation trips GitHub's
secondary rate limit:

```sh
sh <skill-dir>/lib/file_issue.sh <host> <owner/repo> <key> "<title>" <body-file> fix,skill
```

Print each result as soon as it returns (`NEW #N <url>` / `EXISTS #N <url>`).
On exit 3 (gh failure) stop, and report every remaining plan row as
`[PENDING]`; a re-run files only those, because the dedup key makes the rest
`EXISTS`. Running the same batch twice therefore files nothing new.
