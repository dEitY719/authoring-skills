# authoring:command-rename — Repo resolution

Step 1 resolves the remote name to `owner/repo` **and the host that serves
it** before any `gh` call. The procedure is deterministic, so it lives in a
helper rather than here:

```bash
sh "${SKILL_DIR}/lib/resolve-repo.sh" "<remote>"   # default: origin
```

## Contract

| | |
|---|---|
| input | optional remote name, default `origin` |
| stdout | `TARGET_REPO=<owner>/<repo>` then `TARGET_HOST=<host>`, one per line |
| exit 0 | resolved |
| exit 1 | not a git repo, remote missing, URL unparsable, or URL names no host |

On a missing remote it prints the `git remote -v` listing to stderr:

```
Error: remote '<remote-name>' not found. Available remotes:
origin    https://github.com/user/repo.git (fetch)
upstream  https://github.com/org/repo.git (fetch)
```

Both `https://github.com/<owner>/<repo>.git` and
`git@github.com:<owner>/<repo>.git` resolve to `<owner>/<repo>`, and so do the
`ssh://git@host:2222/...` and `https://user:token@host/...` shapes. The host
comes out of that **same** URL, so the pair can never name different servers:

| remote URL | `TARGET_REPO` | `TARGET_HOST` |
|---|---|---|
| `git@github.com:o/r.git` | `o/r` | `github.com` |
| `https://ghes.example.com/o/r` | `o/r` | `ghes.example.com` |
| `ssh://git@ghes.example.com:2222/o/r` | `o/r` | `ghes.example.com` |

## Host targeting rule (dEitY719/dotfiles#1403)

Every `gh` call this skill makes runs as:

```bash
GH_HOST="$TARGET_HOST" gh <sub-command> ... --repo "$TARGET_REPO"
```

`--repo owner/repo` carries no host. A bare `gh` resolves that slug against gh
CLI's own `gh repo set-default` rather than git's remote, and on a dual-host
login (github.com plus a GHES instance) the two can disagree — `gh` then hits
the wrong server with **no error**, which is how an OPEN issue comes back "not
found" and how a comment lands on a stranger's issue #N. `references/issue-creation.md`'s
cross-link is the only place this skill calls `gh` directly; everything else
goes through `gh-issue:create`, which binds its own.

## Failure rule

If the user-specified remote does not exist, fail immediately. **Never**
silently fall back to `origin` — that masks typos and files the issue in the
wrong repo. The helper enforces this; do not paper over its exit 1.

The same rule covers an empty host. A remote with no host in it — a filesystem
mirror such as `/srv/mirrors/repo.git` — used to yield `mirrors/repo`, a slug
with no server to send it to; it now exits 1. An empty `GH_HOST` *is* the
silent-misroute state, so there is nothing safe to continue with.

## What to pass onward

Store `TARGET_REPO` **and** `TARGET_HOST` for this skill's own `gh` calls, and
prefix every one of them with `GH_HOST="$TARGET_HOST"`. `gh-issue:create` resolves
its own repo context from a remote **name** (e.g. `origin`), not `owner/repo` —
pass the original `[remote]` argument (not `TARGET_REPO`) through to it as the
`[remote]` positional in Step 6.
