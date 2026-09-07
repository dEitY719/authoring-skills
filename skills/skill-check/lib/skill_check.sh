#!/bin/sh
# skill_check.sh -- the mechanical half of authoring:skill-check.
#
# Usage: skill_check.sh <SKILL.md-path> [j2 j3 j4 j5 j6 j7 j8 j9 j10 j12]
#   j2..j12 are the auditor's own calls for the ten checks no grep can decide
#   -- 2 Progressive Disclosure, 3 Frontmatter Validity (naming judgment),
#   4 References Directory Usage, 5 Output Report Defined, 6 Help Flag Pattern
#   (verbatim-ness), 7 Step Structure, 8 Options Documentation, 9 Verdict
#   Output, 10 Next-action Hint, 12 Executable Procedure Extraction -- each
#   PASS | WARN | FAIL | N/A, in that check-id order. Pass all ten or none.
#
# stdout: check<TAB>result<TAB>note, one row per decided check, ascending id.
#         With the ten judgments it also emits every row plus a final
#         score<TAB><pass>/<effective-total><TAB><VERDICT>
#         computed per references/report-template.md verdict thresholds.
# exit:   0 report written | 2 bad usage or unreadable file
#
# Read-only: never edits the audited file. Criteria: references/checks.md.
#
# ponytail: Check 16's char count assumes a UTF-8 `wc -m` (forced via
# LC_ALL=C.utf8 below); on a system with no UTF-8 locale installed, `wc -m`
# silently degrades to a byte count and over-reports multibyte (Korean)
# descriptions by ~3x. Upgrade path: shell out to `python3 -c` for length if
# that ever bites in practice.
# ponytail: Check 13's migration-gate state (metadata absent -> FAIL) is
# hardcoded from references/model-recommendation.md Section 3's current
# MIGRATION_COMPLETE=true. If that gate ever reopens, flip GATE_FAIL below.
# ponytail: Check 11's "stale entry" / "outside audited scope" nuance
# (checks.md "Stale entries" paragraph) needs to know which repos are in
# scope for this audit run -- that judgment call stays with the auditor; this
# script only ever emits FAIL (key absent) or N/A (key present), never the
# stale-entry WARN.

set -eu

GATE_FAIL=1 # MIGRATION_COMPLETE=true -> missing metadata.model_recommendation is FAIL, not WARN

file=${1:-}

case $file in
  -h|--help|help)
    echo "usage: skill_check.sh <SKILL.md-path> [j2 j3 j4 j5 j6 j7 j8 j9 j10 j12]"
    exit 0
    ;;
  '')
    echo "skill_check: missing <SKILL.md-path>" >&2
    exit 2
    ;;
esac

[ -r "$file" ] || { echo "skill_check: cannot read '$file'" >&2; exit 2; }

j2='' j3='' j4='' j5='' j6='' j7='' j8='' j9='' j10='' j12=''
if [ "$#" -eq 11 ]; then
  shift
  j2=$1 j3=$2 j4=$3 j5=$4 j6=$5 j7=$6 j8=$7 j9=$8 j10=$9 j12=${10}
elif [ "$#" -ne 1 ]; then
  echo "skill_check: pass the ten judgment results (j2 j3 j4 j5 j6 j7 j8 j9 j10 j12) or none" >&2
  exit 2
fi
for j in "$j2" "$j3" "$j4" "$j5" "$j6" "$j7" "$j8" "$j9" "$j10" "$j12"; do
  case $j in
    ''|PASS|WARN|FAIL|N/A) ;;
    *) echo "skill_check: judgment must be PASS|WARN|FAIL|N/A, got '$j'" >&2; exit 2 ;;
  esac
done

dir=$(cd "$(dirname "$file")" && pwd)
refdir="$dir/references"

# find_upward <start-dir> <name>... -- print the first <start-dir>/<name>
# found while walking up parent directories, stopping at a `.git` dir or `/`.
# Shared by Check 11 (plugin.json) and Check 14 (LICENSE).
find_upward() {
  d=$1; shift
  while :; do
    for n in "$@"; do
      [ -f "$d/$n" ] && { printf '%s\n' "$d/$n"; return; }
    done
    [ -d "$d/.git" ] && return
    [ "$d" = / ] && return
    d=$(dirname "$d")
  done
}

# ---------- Check 1: Line Count ----------
lines=$(wc -l < "$file" | tr -d ' ')
if [ "$lines" -le 100 ]; then
  r1=PASS; n1="$lines lines"
elif [ "$lines" -le 150 ]; then
  r1=WARN; n1="$lines lines (101-150 band, candidate for references/ extraction)"
else
  r1=FAIL; n1="$lines lines (over 150)"
fi

# ---------- frontmatter extraction (shared by checks 13, 14, 16) ----------
# Lines strictly between the first two "---" delimiters.
fm=$(awk '
  /^---[[:space:]]*$/ { n++; next }
  n == 1 { print }
  n >= 2 { exit }
' "$file")

# ---------- Check 11: No Emojis ----------
scan_files="$file"
if [ -d "$refdir" ]; then
  for f in "$refdir"/*.md; do
    [ -e "$f" ] && scan_files="$scan_files $f"
  done
fi
emoji_hits=0
for f in $scan_files; do
  c=$(grep -cP '[\x{1F000}-\x{1FAFF}\x{FE0F}]' "$f" 2>/dev/null || true)
  [ -n "$c" ] || c=0
  emoji_hits=$((emoji_hits + c))
done
if [ "$emoji_hits" -eq 0 ]; then
  r11=PASS; n11='no emoji glyphs in body or references'
else
  # Resolve the allowlist key: <plugin>:<skill>, walking up for a plugin
  # manifest; falls back to the bare pre-split key when none is found
  # (checks.md "Allowlist key resolution").
  manifest=$(find_upward "$dir" .claude-plugin/plugin.json)
  skill_name=$(awk -F': *' '/^name:/ { print $2; exit }' "$file" | tr -d '"' | tr ':' '-')
  [ -n "$skill_name" ] || skill_name=$(basename "$dir")
  if [ -n "$manifest" ]; then
    plugin=$(grep -m1 '"name"' "$manifest" | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
    key="$plugin:$skill_name"
  else
    key="$skill_name"
  fi
  allowlist="$refdir/allowed-emoji-skills.txt"
  if [ ! -f "$allowlist" ]; then
    r11=WARN; n11='allowlist file missing'
  elif grep -qE "^${key}([[:space:]]|#|\$)" "$allowlist" 2>/dev/null; then
    r11='N/A'; n11="allowlisted under $key"
  else
    r11=FAIL; n11="$emoji_hits emoji glyph(s), key '$key' not in allowed-emoji-skills.txt"
  fi
fi

# ---------- Check 13: Model Recommendation Metadata (shape validation) ----------
if printf '%s\n' "$fm" | grep -qE '^disable-model-invocation:[[:space:]]*true'; then
  r13='N/A'; n13='disable-model-invocation: true'
elif ! printf '%s\n' "$fm" | grep -q 'model_recommendation:'; then
  if [ "$GATE_FAIL" -eq 1 ]; then
    r13=FAIL; n13='metadata.model_recommendation absent (migration gate closed)'
  else
    r13=WARN; n13='metadata.model_recommendation absent (migration gate open)'
  fi
else
  tier=$(printf '%s\n' "$fm" | awk -F': *' '/^[[:space:]]*tier:/ { print $2; exit }' | tr -d ' "')
  reason=$(printf '%s\n' "$fm" | awk -F': *' '/^[[:space:]]*reason:/ { print $2; exit }')
  claude=$(printf '%s\n' "$fm" | awk -F': *' '/^[[:space:]]*claude:/ { print $2; exit }' | tr -d ' "')
  nonclaude=$(printf '%s\n' "$fm" | awk -F': *' '/^[[:space:]]*non_claude:/ { print $2; exit }' | tr -d ' "')
  case $tier in
    haiku|sonnet|opus) ;;
    *) r13=FAIL; n13="disallowed tier value '$tier' (allowed: haiku|sonnet|opus)" ;;
  esac
  if [ -z "${r13:-}" ]; then
    if [ -z "$reason" ] || [ -z "$claude" ] || [ -z "$nonclaude" ]; then
      r13=WARN; n13='tier present but reason/compatibility fields incomplete'
    else
      r13=PASS; n13="tier=$tier, reason + compatibility present"
    fi
  fi
fi

# ---------- Check 14: License Declaration ----------
if printf '%s\n' "$fm" | grep -qE '^license:'; then
  r14=PASS; n14='license declared in frontmatter'
else
  found=$(find_upward "$dir" LICENSE LICENSE.md LICENSE.txt)
  if [ -n "$found" ]; then
    spdx=MIT
    grep -qi 'MIT License' "$found" 2>/dev/null || spdx='<SPDX>'
    r14=WARN; n14="no license in frontmatter; add \`license: $spdx\` ($found exists)"
  else
    r14='N/A'; n14='no repo-root LICENSE file found'
  fi
fi

# ---------- Check 15: Capability Declaration Consistency ----------
net_pattern='requests|httpx|urllib|http\.client|socket|aiohttp|curl|wget|fetch\(|https?://'
scripts=''
for d in "$dir/lib" "$dir/scripts"; do
  [ -d "$d" ] && scripts="$scripts $(find "$d" -type f \( -name '*.sh' -o -name '*.py' \) ! -iname '*selftest*' ! -iname 'test_*' ! -iname '*_test.*' 2>/dev/null)"
done
scripts="$scripts $(find "$dir" -maxdepth 1 -type f \( -name '*.sh' -o -name '*.py' \) ! -iname '*selftest*' ! -iname 'test_*' ! -iname '*_test.*' 2>/dev/null)"
# Self-test/fixture files are excluded above -- they exercise capability
# words in synthetic examples, not the skill's own runtime surface.
net_hit=0
for s in $scripts; do
  [ -f "$s" ] || continue
  # Exclude lines that assign a *_pattern= variable (this file's own
  # net_pattern definition line included) -- a helper quoting the signal
  # words as documentation, not calling them, must not self-trip.
  grep -v '_pattern=' "$s" 2>/dev/null | grep -qE "$net_pattern" && net_hit=1
done
if [ -z "$(printf '%s' "$scripts" | tr -d '[:space:]')" ]; then
  r15='N/A'; n15='skill ships no executable helpers'
elif [ "$net_hit" -eq 0 ]; then
  r15=PASS; n15='no network signal in helpers'
elif printf '%s\n' "$fm" | grep -q 'network:'; then
  r15=PASS; n15='network signal present, compatibility.network declared'
else
  r15=WARN; n15='network signal present, compatibility.network not declared'
fi

# ---------- Check 16: Description Length ----------
# Fold a `description:` value -- inline or a `>-`/`|-` block -- to one
# whitespace-normalised line, stopping at the next top-level key.
desc=$(printf '%s\n' "$fm" | awk '
  /^description:[[:space:]]*>-?[[:space:]]*$/ { inblock = 1; next }
  /^description:[[:space:]]*\|-?[[:space:]]*$/ { inblock = 1; next }
  /^description:/ { sub(/^description:[[:space:]]*/, ""); print; next }
  inblock && /^[A-Za-z_-]+:/ { exit }
  inblock { sub(/^[[:space:]]+/, ""); printf "%s ", $0 }
')
# Strip only a wrapping quote pair from an inline `description: "..."` value
# -- internal quotes (e.g. around a trigger phrase) are real description text
# and must stay in the count.
desc=$(printf '%s' "$desc" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
case $desc in
  \"*\") desc=${desc#\"}; desc=${desc%\"} ;;
esac
if [ -z "$desc" ]; then
  r16='N/A'; n16='no description found in frontmatter'
else
  len=$(printf '%s' "$desc" | LC_ALL=C.utf8 wc -m | tr -d ' ')
  if [ "$len" -le 250 ]; then
    r16=PASS; n16="$len characters"
  elif [ "$len" -le 400 ]; then
    r16=WARN; n16="$len characters (251-400 band, needs a justifying comment)"
  else
    r16=FAIL; n16="$len characters (over 400)"
  fi
fi

# ---------- Report ----------
pass=0 fail=0 na=0
out() {
  [ -n "$2" ] || return 0
  printf '%s\t%s\t%s\n' "$1" "$2" "$3"
  case $2 in
    PASS) pass=$((pass + 1)) ;;
    WARN) ;;
    FAIL) fail=$((fail + 1)) ;;
    *)    na=$((na + 1)) ;;
  esac
}

out 1 "$r1" "$n1"
out 2 "$j2" 'auditor judgment'
out 3 "$j3" 'auditor judgment'
out 4 "$j4" 'auditor judgment'
out 5 "$j5" 'auditor judgment'
out 6 "$j6" 'auditor judgment'
out 7 "$j7" 'auditor judgment'
out 8 "$j8" 'auditor judgment'
out 9 "$j9" 'auditor judgment'
out 10 "$j10" 'auditor judgment'
out 11 "$r11" "$n11"
out 12 "$j12" 'auditor judgment'
out 13 "$r13" "$n13"
out 14 "$r14" "$n14"
out 15 "$r15" "$n15"
out 16 "$r16" "$n16"

[ -n "$j2" ] || exit 0

total=$((16 - na))
if [ "$total" -le 0 ]; then
  verdict='N/A'
elif [ "$pass" -eq "$total" ]; then
  verdict=EXCELLENT
else
  pct=$((pass * 100 / total))
  if [ "$pct" -ge 80 ] && [ "$fail" -eq 0 ]; then
    verdict=GOOD
  elif [ "$pct" -ge 60 ] || [ "$fail" -ge 1 ]; then
    verdict='NEEDS WORK'
  else
    verdict=POOR
  fi
fi
printf 'score\t%s/%s\t%s\n' "$pass" "$total" "$verdict"
