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
#   frontmatter         the `---` block survived the rewrite intact and still
#                       carries a non-empty name: and description:
#   uncited-references  every references/*.md beside it is named in SKILL.md
#   orphan-references   every references/*.md named in SKILL.md exists on disk
#   output-block        SKILL.md still carries an Output/Report heading
#
# `frontmatter` deliberately checks structure, not naming policy: whether a
# `name:` should be `foo:bar` or `foo-bar` depends on which world the skill
# lives in, and that judgment stays with the model per
# references/naming-convention.md. What this catches is the rewrite truncating
# or dropping the block.
#
# exit: 0 every row PASS | 1 at least one FAIL | 2 bad usage or unreadable file
#
# Read-only: never edits the file it is pointed at.
#
# ponytail: the two reference-file lists are accumulated as space-separated
# strings and re-split by word splitting, so a file name containing a space
# would be reported as two names. Every skill and reference file in this
# marketplace layout is kebab-case with no spaces (see
# skills/skill-check/references/naming-convention.md), the same call
# lib/skill_check.sh makes for the same reason. Upgrade path if that ever
# breaks: NUL-delimit and read with `while IFS= read -r -d ''`.

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

# 2. The frontmatter block. `awk` walks it once and reports what is missing,
# so a truncated rewrite cannot pass by having lost the whole block.
fm=$(awk '
  NR == 1 && $0 != "---" { print "no --- on line 1"; exit }
  NR > 1 && $0 == "---" { closed = 1; exit }
  NR > 1 && /^name:[[:space:]]*[^[:space:]]/ { name = 1 }
  NR > 1 && /^description:[[:space:]]*([^[:space:]]|>-?[[:space:]]*$)/ { desc = 1 }
  END {
    if (!closed) print "frontmatter block is not closed"
    else if (!name) print "no non-empty name:"
    else if (!desc) print "no non-empty description:"
  }
' "$skill")
if [ -n "$fm" ]; then
  row frontmatter FAIL "$fm"
else
  row frontmatter PASS 'block closed, name: and description: present'
fi

# 3/4. The two directions of the SKILL.md <-> references/ link.
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

# 5. The output contract has to survive the rewrite. The heading must *name*
# the output section, not merely mention it in passing, so the word has to end
# the heading (bar a qualifier): "## Output", "## Final Output",
# "## Step 3: Output the Report" and "## Output Format" all pass, while
# "## Report rationale" does not (codex PR #18 BLOCKER). Judging whether the
# block below it is still correct stays with the model.
if grep -qiE '^#+[[:space:]]+.*(output|report)([[:space:]]+(format|requirements|template|block))?[[:space:]]*$' "$skill"; then
  row output-block PASS 'Output/Report heading present'
else
  row output-block FAIL 'no Output/Report section heading found'
fi

exit "$fails"
