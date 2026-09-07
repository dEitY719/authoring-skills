#!/bin/sh
# selftest.sh -- one runnable check for skill_check.sh. Builds throwaway
# fixtures and asserts the contracts in that helper's header. Run:
# sh lib/selftest.sh

set -eu

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

ok() { printf 'ok   %s\n' "$1"; }
no() { printf 'FAIL %s -- %s\n' "$1" "$2"; fails=$((fails + 1)); }
eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected [$3], got [$2]"; fi
}
# row <output> <check-id>  -> the result column of that check's row
row() { printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$1 == id { print $2 }'; }
# note <output> <check-id> -> the note column of that check's row
note() { printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$1 == id { print $3 }'; }
verdict() { printf '%s\n' "$1" | awk -F'\t' '$1 == "score" { print $3 }'; }

j10='PASS PASS PASS PASS PASS PASS PASS PASS PASS PASS'

# ---------- fixture 1: a clean skill, everything present ----------
mkdir -p "$work/good/authoring/clean/references" "$work/good/.claude-plugin"
cat > "$work/good/.claude-plugin/plugin.json" <<'EOF'
{"name": "authoring"}
EOF
cat > "$work/good/LICENSE" <<'EOF'
MIT License
EOF
good="$work/good/authoring/clean/SKILL.md"
cat > "$good" <<'EOF'
---
name: clean
description: A short, unremarkable description well under the char budget.
license: MIT
metadata:
  model_recommendation:
    tier: sonnet
    reason: "bounded analysis"
    claude: prefer
    non_claude: advisory-only
---
# Clean Skill
Nothing but prose here.
EOF
g=$(sh "$here/skill_check.sh" "$good" $j10)
eq "good: 1 line count"   "$(row "$g" 1)"  PASS
eq "good: 11 no emoji"    "$(row "$g" 11)" PASS
eq "good: 13 metadata"    "$(row "$g" 13)" PASS
eq "good: 14 license"     "$(row "$g" 14)" PASS
eq "good: 15 no scripts"  "$(row "$g" 15)" 'N/A'
eq "good: 16 desc length" "$(row "$g" 16)" PASS
eq "good: verdict"        "$(verdict "$g")" EXCELLENT

# ---------- fixture 2: every mechanical check breaking ----------
mkdir -p "$work/bad/authoring/messy/lib"
bad="$work/bad/authoring/messy/SKILL.md"
{
  echo "---"
  echo "name: messy"
  printf 'description: >-\n'
  printf '  🎉 way over the four-hundred character budget, repeated padding %s to push it past four hundred characters entirely on purpose for this fixture\n' "$(printf 'padding %.0s' $(seq 1 40))"
  echo "---"
  i=0
  while [ "$i" -lt 160 ]; do echo "line $i of filler prose to blow the line budget"; i=$((i + 1)); done
} > "$bad"
cat > "$work/bad/authoring/messy/lib/net.sh" <<'EOF'
#!/bin/sh
curl -s https://example.com/api
EOF
b=$(sh "$here/skill_check.sh" "$bad" $j10)
eq "bad: 1 over 150 lines"  "$(row "$b" 1)"  FAIL
eq "bad: 11 emoji, no allowlist file" "$(row "$b" 11)" WARN
eq "bad: 13 metadata absent" "$(row "$b" 13)" FAIL
eq "bad: 14 no license"     "$(row "$b" 14)" 'N/A'
eq "bad: 15 network undeclared" "$(row "$b" 15)" WARN
eq "bad: 16 over 400 chars" "$(row "$b" 16)" FAIL
eq "bad: verdict"           "$(verdict "$b")" 'NEEDS WORK'

# ---------- fixture 3: a helper that only quotes network words as text ----------
# Regression for the self-reference false positive: a *_pattern= assignment
# line containing the signal words as documentation must not trip Check 15.
mkdir -p "$work/meta/authoring/tool/lib"
meta="$work/meta/authoring/tool/SKILL.md"
cat > "$meta" <<'EOF'
---
name: tool
description: Audits other skills; ships a helper that only documents signal words.
---
# Tool
EOF
cat > "$work/meta/authoring/tool/lib/helper.sh" <<'EOF'
#!/bin/sh
net_pattern='requests|httpx|urllib|curl|wget|fetch\('
EOF
m=$(sh "$here/skill_check.sh" "$meta" $j10)
eq "meta: 15 self-reference is not a network signal" "$(row "$m" 15)" PASS

# ---------- Check 16: description length bands ----------
mkdir -p "$work/warn/authoring/mid"
warn="$work/warn/authoring/mid/SKILL.md"
{
  echo "---"
  echo "name: mid"
  printf 'description: >-\n'
  printf '  %s\n' "$(printf 'x%.0s' $(seq 1 300))"
  echo "---"
} > "$warn"
w=$(sh "$here/skill_check.sh" "$warn" $j10)
eq "warn: 16 in the 251-400 WARN band" "$(row "$w" 16)" WARN

# ---------- mechanical-only mode: no score row without all ten judgments ----------
solo=$(sh "$here/skill_check.sh" "$good")
eq "solo: no score row" "$(printf '%s\n' "$solo" | grep -c '^score' || true)" 0
eq "solo: still reports check 1" "$(row "$solo" 1)" PASS

# ---------- usage errors ----------
if sh "$here/skill_check.sh" >/dev/null 2>&1; then
  no "usage: no argument" "exited 0, expected 2"
else
  ok "usage: no argument"
fi
if sh "$here/skill_check.sh" "$good" PASS >/dev/null 2>&1; then
  no "usage: partial judgments" "exited 0, expected 2"
else
  ok "usage: partial judgments"
fi
if sh "$here/skill_check.sh" "$good" $j10 MAYBE >/dev/null 2>&1; then
  no "usage: too many judgments" "exited 0, expected 2"
else
  ok "usage: too many judgments"
fi
if sh "$here/skill_check.sh" "$work/nope.md" >/dev/null 2>&1; then
  no "usage: unreadable file" "exited 0, expected 2"
else
  ok "usage: unreadable file"
fi

[ "$fails" -eq 0 ] || { printf '\n%s check(s) failed\n' "$fails" >&2; exit 1; }
printf '\nall checks passed\n'
