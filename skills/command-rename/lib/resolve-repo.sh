#!/bin/sh
# resolve-repo.sh -- resolve a git remote name to owner/repo.
#
# Usage: resolve-repo.sh [remote]        remote defaults to "origin"
# stdout: TARGET_REPO=<owner>/<repo>
#         TARGET_HOST=<host>
# exit:   0 resolved | 1 not a git repo, remote missing, or unparsable URL
#
# Repo and host are read from one and the same remote URL, so they can never
# name different servers. `--repo owner/repo` carries no host: a bare `gh`
# resolves that slug against gh CLI's own `gh repo set-default` rather than
# git's remote, and on a dual-host login (github.com + a GHES instance) the two
# can disagree and `gh` hits the wrong server with no error at all
# (dEitY719/dotfiles#1403). Every caller must therefore run
# `GH_HOST="$TARGET_HOST" gh ... --repo "$TARGET_REPO"`.
#
# Never falls back to another remote: a typo must fail, not file the issue in
# the wrong repo (references/repo-resolution.md -> "Failure rule"). Never
# returns an empty TARGET_HOST either — that is the silent-misroute state
# itself, so a URL with no host (a local path, say) exits 1 rather than
# handing back a slug nothing can safely target.
#
# SSOT for the parse is dotfiles `shell-common/functions/gh_host.sh`
# (`_gh_parse_owner_repo_url` / `_gh_host_from_url`), which
# `gh-issue-skills/lib/resolve-target.sh` sources via `lib/vendor/`. This repo
# has no vendor tree, so the lines are reimplemented rather than sourced. The
# one deliberate difference: the SSOT matches an allowlist of known GitHub
# domains, and copying a domain list into a second file is the drift this
# family forbids — the host here is whatever the URL names, which is also what
# the owner/repo parse below has always done.

set -eu

remote=${1:-origin}

case $remote in
  -h|--help|help)
    echo "usage: resolve-repo.sh [remote]   # prints TARGET_REPO=<owner>/<repo>"
    exit 0
    ;;
esac

git rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "resolve-repo: not a git repository" >&2
  exit 1
}

url=$(git remote get-url "$remote" 2>/dev/null) || {
  echo "Error: remote '$remote' not found. Available remotes:" >&2
  git remote -v >&2
  exit 1
}

# https://host/<owner>/<repo>[.git] and git@host:<owner>/<repo>[.git]
repo=$(printf '%s\n' "$url" | sed -E 's#/+$##; s#\.git$##; s#^.*[:/]([^/:]+/[^/]+)$#\1#')

case $repo in
  */*) ;;
  *)
    echo "resolve-repo: cannot parse owner/repo from '$url'" >&2
    exit 1
    ;;
esac

# scheme, then optional user[:token]@, then everything from the first `:` or
# `/`. That covers https://host/o/r, git+https://host/o/r, git@host:o/r,
# ssh://git@host:2222/o/r and https://user:token@host/o/r alike; the port and
# the path both fall off with the same expression.
host=$(printf '%s\n' "$url" | sed -E 's#^[A-Za-z0-9+.-]+://##; s#^[^/@]*@##; s#[:/].*$##')

# A local path or a relative remote leaves nothing host-shaped behind. Testing
# for a hostname character rather than a dotted domain keeps a single-label
# intranet GHES working while still rejecting `` and `..`.
if ! printf '%s' "$host" | grep -q '[A-Za-z0-9]'; then
  echo "resolve-repo: cannot parse a host from '$url' -- refusing to return a repo with no host (dEitY719/dotfiles#1403)" >&2
  exit 1
fi

echo "TARGET_REPO=$repo"
echo "TARGET_HOST=$host"
