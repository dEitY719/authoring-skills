#!/bin/sh
# skill-check's check count is written by hand in many places, and CI never
# compared them to the real number: "eighteen" outlived Check 19 by two
# releases in .codex-plugin/plugin.json (issue #65, #74). The `Check <N>`
# headings in references/checks.md are the SSOT; every prose count below must
# equal their number.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

n=$(grep -c '^#\{1,6\} Check [0-9][0-9]*:' skills/skill-check/references/checks.md || :)
[ "$n" -gt 0 ] || { echo "FAIL no 'Check <N>:' headings in checks.md" >&2; exit 1; }
# The helper's score denominator is the same count, in code rather than prose.
grep -q "^total=\$(($n - na))\$" skills/skill-check/lib/skill_check.sh ||
  { echo "FAIL skills/skill-check/lib/skill_check.sh: score denominator is not total=\$(($n - na))" >&2; exit 1; }

# A line is cut at its first `sh-check`, whose own "ten criteria" share rows
# and the codex longDescription with skill-check's count; in an HTML `<td>`
# that row's cells sit on later lines, so the cut runs to its `</tr>`. Only
# counted nouns match, so `0.1.19`, `#19`, `Check 19` and `7/17 checks passed`
# are ignored. checks.md is read only to its intro line: its body names
# per-group counts ("These three checks"). Every file must yield a count, so a
# rewording the patterns miss fails instead of silently dropping coverage.
LC_ALL=C awk -v want="$n" '
BEGIN {
  split("one two three four five six seven eight nine ten eleven twelve " \
        "thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty " \
        "twenty-one twenty-two twenty-three twenty-four twenty-five", w, " ")
  for (i in w) num[w[i]] = i
  words = "(twenty-(one|two|three|four|five)|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty)"
  noun = "[ -](structure|checks?|criteria|check definitions|total)"
  bad = 0
}
function report(got) {
  if (got != want) {
    printf "FAIL %s:%d says %s, expected %s (checks.md has %s Check headings)\n", FILENAME, FNR, got, want, want > "/dev/stderr"
    bad = 1
  }
  seen++; hits[FILENAME]++
}
{
  if (FNR == 1) insh = 0
  if (FILENAME ~ /references\/checks[.]md$/ && FNR > 3) next
  s = tolower($0)
  if (insh) { if (index(s, "</tr>")) insh = 0; next }
  p = index(s, "sh-check")
  if (p) {
    if (FILENAME ~ /[.]html$/ && index(s, "<td") && !index(substr(s, p), "</tr>")) insh = 1
    s = substr(s, 1, p - 1)
  }
  t = " " s
  while (match(t, "[^0-9./#-][0-9]+" noun)) {
    m = substr(t, RSTART + 1, RLENGTH - 1); sub(/[^0-9].*/, "", m); report(m + 0)
    t = substr(t, RSTART + RLENGTH)
  }
  t = s
  while (match(t, "[0-9]+(개 (기준|검사|정의|전부|항목)| − n/a)")) {
    m = substr(t, RSTART, RLENGTH); sub(/[^0-9].*/, "", m); report(m + 0)
    t = substr(t, RSTART + RLENGTH)
  }
  t = " " s
  while (match(t, "[^a-z-]" words noun)) {
    m = substr(t, RSTART + 1, RLENGTH - 1)
    sub(/[ -](structure|checks?|criteria|check definitions|total).*$/, "", m)
    report(num[m] + 0)
    t = substr(t, RSTART + RLENGTH)
  }
}
END {
  for (i = 1; i < ARGC; i++)
    if (!hits[ARGV[i]]) { printf "FAIL %s: no prose count found\n", ARGV[i] > "/dev/stderr"; bad = 1 }
  if (bad) exit 1
  printf "ok   %d prose counts match checks.md (%s checks)\n", seen, want
}
' skills/skill-check/references/checks.md skills/skill-check/SKILL.md \
  skills/skill-check/references/help.md \
  skills/skill-check/references/report-template.md \
  README.md CLAUDE.md GEMINI.md .codex-plugin/plugin.json docs/index.html \
  docs/skill-guides/skill-check.md docs/skill-guides/skill-check.html \
  docs/skill-guides/skill-create.md docs/skill-guides/skill-create.html \
  docs/skill-guides/skill-refactor.md docs/skill-guides/skill-refactor.html \
  docs/skill-output/skill-check-usage.md docs/skill-output/skill-check-usage.html
