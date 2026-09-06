#!/bin/sh
# resolve-repo.sh -- resolve a git remote name to owner/repo.
#
# Usage: resolve-repo.sh [remote]        remote defaults to "origin"
# stdout: TARGET_REPO=<owner>/<repo>
# exit:   0 resolved | 1 not a git repo, remote missing, or unparsable URL
#
# Never falls back to another remote: a typo must fail, not file the issue in
# the wrong repo (references/repo-resolution.md -> "Failure rule").

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

echo "TARGET_REPO=$repo"
