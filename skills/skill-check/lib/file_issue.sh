#!/bin/sh
# file_issue.sh -- file one authoring:skill-check finding issue, idempotently.
#
# Usage:
#   file_issue.sh <host> <owner/repo> <key> <title> <body-file> [labels]
#       Create the issue unless an OPEN issue in <owner/repo> already carries
#       the line `skill-check-key: <key>`. labels is comma-separated; only the
#       ones that already exist on the repo are applied (never created).
#       Prints `NEW #<n> <url>` or `EXISTS #<n> <url>`.
#   file_issue.sh --check <host> <owner/repo> <key>
#       Dedup lookup only, for the Issue Plan: `EXISTS #<n> <url>` or `NEW`.
#   file_issue.sh --preflight <host> <owner/repo>
#       `OK`, or `SKIP <reason>` when gh is not logged in to <host> or the
#       repo has issues disabled / is unreachable.
#
# exit: 0 ok (including SKIP) | 2 usage | 3 gh failure
# Every gh call pins GH_HOST=<host> and -R <owner/repo>: with several hosts
# logged in, an unpinned call silently lands on another server. The body
# must contain the key line, or the next run could not find this issue.
# Set SKILL_CHECK_GH to substitute the gh binary (tests).

set -eu

GH=${SKILL_CHECK_GH:-gh}

usage() { printf 'file_issue: %s\n' "$1" >&2; exit 2; }

valid_target() {
  case $1 in ''|*[!A-Za-z0-9.:-]*) usage "bad host: $1" ;; esac
  case $2 in */*/*|/*|*/) usage "bad repo: $2" ;; ?*/?*) ;; *) usage "bad repo: $2" ;; esac
}
# The key is spliced into a jq program, so only plugin:skill characters pass.
valid_key() {
  case $1 in ''|*[!A-Za-z0-9._:-]*) usage "bad key: $1" ;; esac
}

# existing <host> <repo> <key> -- "#<n> <url>" of the first open issue whose
# body has the exact key line; empty when none. A plain listing, not
# `--search`: the search index lags, so a quick re-run (e.g. after a PENDING
# stop) would miss an issue it just filed and file it twice.
# shortcut: only the newest 1000 open issues are read; page further if a
# target repo ever carries more.
existing() {
  out=$(GH_HOST=$1 "$GH" issue list -R "$2" --state open --limit 1000 \
    --json number,url,body \
    --jq ".[] | select(any(.body | split(\"\\n\")[]; rtrimstr(\"\\r\") == \"skill-check-key: $3\")) | \"#\\(.number) \\(.url)\"") || return 3
  printf '%s\n' "$out" | head -n1
}

case ${1:-} in
  --preflight)
    [ $# -eq 3 ] || usage "usage: file_issue.sh --preflight <host> <owner/repo>"
    valid_target "$2" "$3"
    if ! "$GH" auth status --hostname "$2" >/dev/null 2>&1; then
      echo "SKIP gh not logged in to $2"; exit 0
    fi
    en=$(GH_HOST=$2 "$GH" repo view "$3" --json hasIssuesEnabled --jq .hasIssuesEnabled 2>/dev/null || true)
    if [ "$en" = true ]; then echo OK; else echo "SKIP issues disabled or repo unreachable: $3"; fi
    exit 0 ;;
  --check)
    [ $# -eq 4 ] || usage "usage: file_issue.sh --check <host> <owner/repo> <key>"
    valid_target "$2" "$3"; valid_key "$4"
    hit=$(existing "$2" "$3" "$4") || exit 3
    if [ -n "$hit" ]; then echo "EXISTS $hit"; else echo NEW; fi
    exit 0 ;;
  -h|--help|help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

[ $# -eq 5 ] || [ $# -eq 6 ] || usage "usage: file_issue.sh <host> <owner/repo> <key> <title> <body-file> [labels]"
host=$1; repo=$2; key=$3; title=$4; body=$5; labels=${6:-}
valid_target "$host" "$repo"; valid_key "$key"
[ -n "$title" ] || usage "empty title"
[ -f "$body" ] || usage "body file not found: $body"
grep -qxF "skill-check-key: $key" "$body" || usage "body file lacks the line 'skill-check-key: $key'"

hit=$(existing "$host" "$repo" "$key") || exit 3
if [ -n "$hit" ]; then echo "EXISTS $hit"; exit 0; fi

set -- --title "$title" --body-file "$body"
if [ -n "$labels" ]; then
  have=$(GH_HOST=$host "$GH" label list -R "$repo" --limit 500 --json name --jq '.[].name') || exit 3
  old_ifs=$IFS; IFS=,
  for l in $labels; do
    if printf '%s\n' "$have" | grep -qxF -- "$l"; then set -- "$@" --label "$l"; fi
  done
  IFS=$old_ifs
fi
url=$(GH_HOST=$host "$GH" issue create -R "$repo" "$@") || exit 3
url=$(printf '%s\n' "$url" | tail -n1)
echo "NEW #${url##*/} $url"
