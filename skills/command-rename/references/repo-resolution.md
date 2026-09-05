# authoring:command-rename — Repo resolution

Substeps for Step 1 "resolve target family" — the remote → `owner/repo`
resolution used before any `gh` call. Same pattern every skill in this repo
uses; kept here so SKILL.md holds only the workflow.

## Substeps

1. `git rev-parse --show-toplevel` — confirm we are in a git repo.

2. Determine the target remote:
   - If the user passed a `[remote]` positional, use it.
   - Otherwise default to `origin`.

3. Validate the remote and resolve owner/repo:

   ```bash
   git remote get-url <remote-name>
   ```

   If this fails, list `git remote -v` and stop:

   ```
   Error: remote '<remote-name>' not found. Available remotes:
   origin    https://github.com/user/repo.git (fetch)
   upstream  https://github.com/org/repo.git (fetch)
   ```

4. Extract `owner/repo` from the URL:
   - `https://github.com/<owner>/<repo>.git` → `<owner>/<repo>`
   - `git@github.com:<owner>/<repo>.git` → `<owner>/<repo>`

Store as `TARGET_REPO` for use in this skill's own `gh` calls. `gh-issue:create`
resolves its own repo context from a remote **name** (e.g. `origin`), not
`owner/repo` — pass the original `[remote]` argument (not `TARGET_REPO`)
through to it as the `[remote]` positional in Step 6.

## Failure rule

If the user-specified remote does not exist, fail immediately with the list
of available remotes. **Never** silently fall back to `origin` — that masks
typos and files the issue in the wrong repo.
