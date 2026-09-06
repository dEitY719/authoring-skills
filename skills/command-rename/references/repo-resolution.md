# authoring:command-rename — Repo resolution

Step 1 resolves the remote name to `owner/repo` before any `gh` call. The
procedure is deterministic, so it lives in a helper rather than here:

```bash
sh "${SKILL_DIR}/lib/resolve-repo.sh" "<remote>"   # default: origin
```

## Contract

| | |
|---|---|
| input | optional remote name, default `origin` |
| stdout | `TARGET_REPO=<owner>/<repo>` |
| exit 0 | resolved |
| exit 1 | not a git repo, remote missing, or URL unparsable |

On a missing remote it prints the `git remote -v` listing to stderr:

```
Error: remote '<remote-name>' not found. Available remotes:
origin    https://github.com/user/repo.git (fetch)
upstream  https://github.com/org/repo.git (fetch)
```

Both `https://github.com/<owner>/<repo>.git` and
`git@github.com:<owner>/<repo>.git` resolve to `<owner>/<repo>`.

## Failure rule

If the user-specified remote does not exist, fail immediately. **Never**
silently fall back to `origin` — that masks typos and files the issue in the
wrong repo. The helper enforces this; do not paper over its exit 1.

## What to pass onward

Store `TARGET_REPO` for this skill's own `gh` calls. `gh-issue:create` resolves
its own repo context from a remote **name** (e.g. `origin`), not `owner/repo` —
pass the original `[remote]` argument (not `TARGET_REPO`) through to it as the
`[remote]` positional in Step 6.
