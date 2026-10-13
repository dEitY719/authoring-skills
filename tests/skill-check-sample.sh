#!/bin/sh
# docs/skill-output/skill-check-usage.{md,html} show a sample skill-check
# report and print the command that reproduces its mechanical score. Run that
# command, read straight from the .md page so page and test cannot diverge,
# and fail when its `score` row no longer matches what the pages claim
# (issue #72). Only the score row is asserted: the auditor arguments on the
# page are documented reasoning, not something CI re-judges.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
md=$root/docs/skill-output/skill-check-usage.md
html=$root/docs/skill-output/skill-check-usage.html

fail() {
  echo "FAIL $*" >&2
  exit 1
}

# The command spans two lines joined by a trailing backslash.
args=$(sed -n '/^sh skills\/skill-check\/lib\/skill_check\.sh /{N;s/\\\n//;s/^sh //;p;q;}' "$md")
[ -n "$args" ] || fail "no skill_check.sh reproduce command in $md"

# "Score: 17/17 checks passed (...) · Verdict: EXCELLENT" -> "17/17 EXCELLENT"
want=$(sed -n 's/^Score: \([0-9]*\/[0-9]*\) checks passed.*Verdict: \([A-Z_]*\).*/\1 \2/p' "$md")
[ -n "$want" ] || fail "no 'Score: ... Verdict: ...' line in $md"

cd "$root"
set -f
# shellcheck disable=SC2086 # split the page's argument list into words on purpose
got=$(sh $args | awk -F '\t' '$1 == "score" { print $2 " " $3 }')
set +f
[ -n "$got" ] || fail "skill_check.sh printed no score row"
[ "$got" = "$want" ] || fail "skill_check.sh says '$got' but $md says '$want'"

frac=${got% *}
verdict=${got#* }
grep -q "<strong>$frac checks passed</strong>" "$html" ||
  fail "$html score is not $frac"
grep -q "Verdict: <strong[^>]*>$verdict</strong>" "$html" ||
  fail "$html verdict is not $verdict"
for page in "$md" "$html"; do
  grep -qF "score  $frac  $verdict" "$page" ||
    fail "$page reproduce comment is not 'score  $frac  $verdict'"
done

echo "ok   skill-check sample page matches skill_check.sh ($got)"
