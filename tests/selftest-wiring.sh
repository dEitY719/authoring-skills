#!/bin/sh
# Every `skills/<name>/lib/selftest.sh` needs a one-line `tests/` wrapper: CI
# discovers checks only under the repo-root `tests/`, so a selftest nobody
# wrapped never runs and its helper can regress unseen. That is how
# skill-check's suite stayed unwired from PR #16 to issue #17. This asserts the
# wiring itself, so the next helper cannot repeat it.
set -eu
root=$(dirname "$0")/..
rc=0
for selftest in "$root"/skills/*/lib/selftest.sh; do
  [ -f "$selftest" ] || continue
  skill=$(basename "$(dirname "$(dirname "$selftest")")")
  # Match on the path a wrapper execs, not on the wrapper's filename, so the
  # naming convention stays a convention rather than a second thing to obey.
  if grep -q "skills/$skill/lib/selftest.sh" "$root"/tests/*.sh 2>/dev/null; then
    echo "ok   $skill selftest is wired into tests/"
  else
    echo "FAIL $skill has lib/selftest.sh but no tests/ wrapper runs it" >&2
    rc=1
  fi
done
if [ "$rc" -eq 0 ]; then
  echo "all selftests wired"
fi
exit "$rc"
