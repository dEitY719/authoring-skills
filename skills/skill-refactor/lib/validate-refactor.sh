#!/bin/sh
# validate-refactor.sh -- the mechanical half of authoring:skill-refactor
# Step 3c. Everything it decides is a measurement, so the skill reports what
# was measured instead of what it remembers writing.
#
# Usage: validate-refactor.sh <SKILL.md-path>
#
# stdout: check<TAB>PASS|FAIL<TAB>detail, one row per gate, in this order:
#   line-count          SKILL.md is at or under the 100-line limit; the detail
#                       carries the measured count, which is what the Step 4
#                       report's lines_before= / lines_after= values come from
#   uncited-references  every references/*.md beside it is named in SKILL.md
#   orphan-references   every references/*.md named in SKILL.md exists on disk
#   output-block        SKILL.md still carries an Output/Report heading
#
# exit: 0 every row PASS | 1 at least one FAIL | 2 bad usage or unreadable file
#
# Read-only: never edits the file it is pointed at.

set -eu

die() {
  printf '%s\n' "$1" >&2
  exit 2
}

[ $# -eq 1 ] || die 'usage: validate-refactor.sh <SKILL.md-path>'
skill=$1
if [ ! -f "$skill" ] || [ ! -r "$skill" ]; then
  die "not a readable file: $skill"
fi

refdir=$(dirname "$skill")/references
fails=0

row() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
  if [ "$2" = FAIL ]; then fails=1; fi
}

# 1. Line count. awk END{NR} rather than `wc -l` so a file with no trailing
# newline still counts its last line.
lines=$(awk 'END { print NR }' "$skill")
if [ "$lines" -le 100 ]; then
  row line-count PASS "$lines lines (limit 100)"
else
  row line-count FAIL "$lines lines (limit 100)"
fi

# 2/3. The two directions of the SKILL.md <-> references/ link.
uncited=''
if [ -d "$refdir" ]; then
  for f in "$refdir"/*.md; do
    [ -e "$f" ] || continue
    base=${f##*/}
    grep -qF "$base" "$skill" || uncited="$uncited $base"
  done
fi
if [ -n "$uncited" ]; then
  row uncited-references FAIL "not named in SKILL.md:$uncited"
else
  row uncited-references PASS 'every references/*.md is cited'
fi

# `references/` is 11 characters, hence the RSTART+11 / RLENGTH-11 offsets.
named=$(awk '{
  while (match($0, /references\/[A-Za-z0-9._-]+\.md/)) {
    print substr($0, RSTART + 11, RLENGTH - 11)
    $0 = substr($0, RSTART + RLENGTH)
  }
}' "$skill" | sort -u)
orphan=''
for base in $named; do
  [ -f "$refdir/$base" ] || orphan="$orphan $base"
done
if [ -n "$orphan" ]; then
  row orphan-references FAIL "cited but missing:$orphan"
else
  row orphan-references PASS 'every cited reference file exists'
fi

# 4. The output contract has to survive the rewrite. A heading is the cheapest
# reliable marker; judging whether the block below it is still correct stays
# with the model.
if grep -qiE '^#+[[:space:]]+.*(output|report)' "$skill"; then
  row output-block PASS 'Output/Report heading present'
else
  row output-block FAIL 'no Output/Report heading found'
fi

exit "$fails"
