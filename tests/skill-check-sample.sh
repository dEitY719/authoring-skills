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
  echo "     rerun the page's command and update both sample pages to match" >&2
  exit 1
}

# The command spans two lines joined by a trailing backslash.
cmd=$(sed -n '/^sh skills\/skill-check\/lib\/skill_check\.sh /{N;p;q;}' "$md")
[ -n "$cmd" ] || fail "no skill_check.sh reproduce command in $md"
case $cmd in
  *'\
'*) ;;
  *) fail "reproduce command in $md must be two lines joined by a trailing backslash" ;;
esac
args=$(printf '%s\n' "$cmd" | sed 'N;s/\\\n//;s/^sh //')

# "Score: 17/17 checks passed (...) · Verdict: EXCELLENT" -> "17/17 EXCELLENT"
# (a verdict may hold a space or slash: NEEDS WORK, N/A)
want=$(sed -n 's/^Score: \([0-9]*\/[0-9]*\) checks passed.*Verdict: \([A-Z][A-Z \/]*[A-Z]\).*/\1 \2/p' "$md")
[ -n "$want" ] || fail "no 'Score: ... Verdict: ...' line in $md"

cd "$root"
set -f
# shellcheck disable=SC2086 # split the page's argument list into words on purpose
got=$(sh $args | awk -F '\t' '$1 == "score" { print $2 " " $3 }')
set +f
[ -n "$got" ] || fail "skill_check.sh printed no score row"
[ "$got" = "$want" ] || fail "skill_check.sh says '$got' but $md says '$want'"

frac=${got%% *}
verdict=${got#* }
# The .html page must show the same reproduce command as the .md page.
while IFS= read -r line; do
  grep -qF -- "$line" "$html" || fail "$html reproduce command differs from $md: $line"
done <<EOF
$cmd
EOF
grep -q "<strong>$frac checks passed</strong>" "$html" ||
  fail "$html score is not $frac"
grep -q "Verdict: <strong[^>]*>$verdict</strong>" "$html" ||
  fail "$html verdict is not $verdict"
grep -q "pill--verdict\">Verdict: $verdict<" "$html" ||
  fail "$html header verdict pill is not $verdict"
for page in "$md" "$html"; do
  grep -qF "score  $frac  $verdict" "$page" ||
    fail "$page reproduce comment is not 'score  $frac  $verdict'"
done

echo "ok   skill-check sample page matches skill_check.sh ($got)"
