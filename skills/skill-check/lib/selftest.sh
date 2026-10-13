#!/bin/sh
# selftest.sh -- one runnable check for skill_check.sh. Builds throwaway
# fixtures and asserts the contracts in that helper's header. Run:
# sh lib/selftest.sh

# shellcheck disable=SC2086 # $j10/$j11 are word-split on purpose: one arg per judgment

set -eu

here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
# The i87 unreadable-subdir fixture is mode 000 while it runs; restore it first
# so an interrupt there cannot leave an undeletable temp dir behind.
trap 'chmod u+rwx "$work/unread/build" 2>/dev/null; rm -rf "$work"' EXIT
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
# mkskill <path> -- write stdin to <path>, creating its parent dir first.
mkskill() { mkdir -p "$(dirname "$1")"; cat > "$1"; }
# A real emoji glyph (U+1F389 PARTY POPPER) for the fixtures below, generated
# at runtime via octal escapes so this SOURCE FILE carries no banned
# codepoint itself -- the repo's emoji gate only allowlists
# skills/skill-check/references/, not lib/ (codex PR #16 BLOCKER: a literal
# emoji glyph here failed CI's "No emojis in tracked text" check).
emoji=$(printf '\360\237\216\211')

# The eleven judged results (2-10, 12, 19), and the pre-Check-19 ten-result form.
j11='PASS PASS PASS PASS PASS PASS PASS PASS PASS PASS PASS'
j10='PASS PASS PASS PASS PASS PASS PASS PASS PASS PASS'

# ---------- fixture 1: a clean skill, everything present ----------
mkdir -p "$work/good/authoring/clean/references"
mkskill "$work/good/.claude-plugin/plugin.json" <<'EOF'
{"name": "authoring"}
EOF
mkskill "$work/good/LICENSE" <<'EOF'
MIT License
EOF
good="$work/good/authoring/clean/SKILL.md"
mkskill "$good" <<'EOF'
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
g=$(sh "$here/skill_check.sh" "$good" $j11)
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
  printf '  %s way over the four-hundred character budget, repeated padding %s to push it past four hundred characters entirely on purpose for this fixture\n' "$emoji" "$(printf 'padding %.0s' $(seq 1 40))"
  echo "---"
  i=0
  while [ "$i" -lt 160 ]; do echo "line $i of filler prose to blow the line budget"; i=$((i + 1)); done
} | mkskill "$bad"
mkskill "$work/bad/authoring/messy/lib/net.sh" <<'EOF'
#!/bin/sh
curl -s https://example.com/api
EOF
b=$(sh "$here/skill_check.sh" "$bad" $j11)
eq "bad: 1 over 150 lines"  "$(row "$b" 1)"  FAIL
eq "bad: 11 emoji, key not in the real allowlist" "$(row "$b" 11)" FAIL
eq "bad: 13 metadata absent" "$(row "$b" 13)" FAIL
eq "bad: 14 no license"     "$(row "$b" 14)" 'N/A'
eq "bad: 15 network undeclared" "$(row "$b" 15)" WARN
eq "bad: 16 over 400 chars" "$(row "$b" 16)" FAIL
eq "bad: verdict"           "$(verdict "$b")" 'NEEDS WORK'

# ---------- fixture 3: a helper that only quotes network words as text ----------
# Regression for the self-reference false positive: a *_pattern= assignment
# line containing the signal words as documentation must not trip Check 15.
meta="$work/meta/authoring/tool/SKILL.md"
mkskill "$meta" <<'EOF'
---
name: tool
description: Audits other skills; ships a helper that only documents signal words.
---
# Tool
EOF
mkskill "$work/meta/authoring/tool/lib/helper.sh" <<'EOF'
#!/bin/sh
net_pattern='requests|httpx|urllib|curl|wget|fetch\('
EOF
m=$(sh "$here/skill_check.sh" "$meta" $j11)
eq "meta: 15 self-reference is not a network signal" "$(row "$m" 15)" PASS

# ---------- fixture 4: a skill trying to self-allowlist its own emoji ----------
# Regression for the codex PR #16 BLOCKER: the allowlist must resolve to this
# tool's OWN references/ dir, never the audited skill's -- otherwise any
# skill could ship its own allowed-emoji-skills.txt naming itself and bypass
# the ban entirely.
mkdir -p "$work/sneaky/evil/.claude-plugin"
mkskill "$work/sneaky/evil/.claude-plugin/plugin.json" <<'EOF'
{"name": "evil"}
EOF
sneaky="$work/sneaky/evil/sneaky/SKILL.md"
mkskill "$sneaky" <<EOF
---
name: sneaky
description: Ships its own forged allowlist naming itself, to try to bypass Check 11.
---
Party time $emoji
EOF
mkskill "$work/sneaky/evil/sneaky/references/allowed-emoji-skills.txt" <<'EOF'
evil:sneaky   # forged self-allowlist entry -- must be ignored
EOF
s=$(sh "$here/skill_check.sh" "$sneaky" $j11)
eq "sneaky: 11 forged local allowlist is ignored" "$(row "$s" 11)" FAIL

# ---------- fixture 5: a decoy top-level field must not satisfy Check 15 ----------
# Regression for the codex PR #16 BLOCKER: only compatibility.network counts,
# not any line containing the substring "network:" anywhere in frontmatter.
mkdir -p "$work/decoy/authoring/net/lib"
decoy="$work/decoy/authoring/net/SKILL.md"
mkskill "$decoy" <<'EOF'
---
name: net
description: Has a decoy top-level field that merely contains the word network.
x-network: this is not compatibility.network
---
# Net
EOF
mkskill "$work/decoy/authoring/net/lib/net.sh" <<'EOF'
#!/bin/sh
curl -s https://example.com/api
EOF
d=$(sh "$here/skill_check.sh" "$decoy" $j11)
eq "decoy: 15 decoy field does not satisfy declaration" "$(row "$d" 15)" WARN

# ---------- Check 16: description length bands ----------
# Shared 300-char filler for the 251-400 WARN band, reused by all three
# fixtures below instead of regenerating it per block.
mid300=$(printf 'x%.0s' $(seq 1 300))

warn="$work/warn/authoring/mid/SKILL.md"
{
  echo "---"
  echo "name: mid"
  printf 'description: >-\n'
  printf '  %s\n' "$mid300"
  echo "---"
} | mkskill "$warn"
w=$(sh "$here/skill_check.sh" "$warn" $j11)
eq "warn: 16 in the 251-400 WARN band, no justifying comment" "$(row "$w" 16)" WARN

# Same band, but with a justifying comment above description: -- must clear
# the WARN even though the length is unchanged (issue #28).
justified="$work/justified/authoring/mid2/SKILL.md"
{
  echo "---"
  echo "name: mid2"
  echo "# Description is 300 chars, over check 16's 250-char band, on purpose."
  printf 'description: >-\n'
  printf '  %s\n' "$mid300"
  echo "---"
} | mkskill "$justified"
j=$(sh "$here/skill_check.sh" "$justified" $j11)
eq "justified: 16 PASSes in the 251-400 band with a Check 16 comment" "$(row "$j" 16)" PASS

# A comment that merely contains the word "check" (no "16") must NOT satisfy
# it -- the match is scoped to "check 16"/"check-16", not any mention of
# "check", so a decoy comment must not silence a real WARN.
decoy16="$work/decoy16/authoring/mid3/SKILL.md"
{
  echo "---"
  echo "name: mid3"
  echo "# Check this description carefully before editing."
  printf 'description: >-\n'
  printf '  %s\n' "$mid300"
  echo "---"
} | mkskill "$decoy16"
d16=$(sh "$here/skill_check.sh" "$decoy16" $j11)
eq "decoy16: a bare 'check' comment does not satisfy Check 16" "$(row "$d16" 16)" WARN

# A trailing digit after "16" must not false-match (agy review, PR #29
# FOLLOW-UP) -- a workflow-run ID like "check-1601" or a heading like
# "Check 160 lines" is not a Check 16 justification.
decoytrail="$work/decoytrail/authoring/mid4/SKILL.md"
{
  echo "---"
  echo "name: mid4"
  echo "# See workflow run check-1601 for why this failed once."
  printf 'description: >-\n'
  printf '  %s\n' "$mid300"
  echo "---"
} | mkskill "$decoytrail"
dt=$(sh "$here/skill_check.sh" "$decoytrail" $j11)
eq "decoytrail: 'check-1601' (trailing digit) does not satisfy Check 16" "$(row "$dt" 16)" WARN

# ---------- Checks 17-18: portability ----------
# port <name> -- write stdin as a minimal SKILL.md at $work/port/<name>/, and
# print its path. Extra bundle files are written by the caller afterwards.
port() {
  p="$work/port/$1/SKILL.md"
  { printf -- '---\nname: %s\ndescription: Portability fixture.\n---\n' "$1"; cat; } | mkskill "$p"
  printf '%s\n' "$p"
}
fence='```'

p=$(port escape <<'EOF'
Run `bash ../../../lib/x.sh` first.
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "escape: 17 path outside the skill dir WARNs" "$(row "$o" 17)" WARN
case $(note "$o" 17) in
  *'SKILL.md:5 -> ../../../lib/x.sh'*) ok "escape: 17 note names file:line -> path" ;;
  *) no "escape: 17 note names file:line -> path" "$(note "$o" 17)" ;;
esac
eq "escape: 18 no plugin-root use" "$(row "$o" 18)" 'N/A'

# A reference file may climb back to its own skill root -- still inside.
p=$(port inside <<'EOF'
See [a](references/a.md).
EOF
)
mkskill "$work/port/inside/references/a.md" <<'EOF'
Back to [the entry](../SKILL.md) and [b](./b.md).
EOF
o=$(sh "$here/skill_check.sh" "$p")
eq "inside: 17 in-skill references PASS" "$(row "$o" 17)" PASS

# ... but one level more from references/ leaves it: depth is per-file.
mkskill "$work/port/inside/references/c.md" <<'EOF'
Sibling: [x](../../other/references/x.md).
EOF
o=$(sh "$here/skill_check.sh" "$p")
eq "inside: 17 a ref file's ../../ escapes" "$(row "$o" 17)" WARN

p=$(port fenced <<EOF
Example of what not to do:
$fence
bash ../../../lib/x.sh
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "fenced: 17 ../ inside a code fence is an example" "$(row "$o" 17)" PASS

# A skill-dir variable names an executed path, so `${SKILL_DIR}/../` counts
# even inside a fence (issue #34 pattern 1).
p=$(port skilldirvar <<EOF
$fence
python3 "\${SKILL_DIR}/../other/x.py"
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "skilldirvar: 17 fenced \${SKILL_DIR}/../ WARNs" "$(row "$o" 17)" WARN

p=$(port skilldirin <<EOF
$fence
python3 "\$SKILL_DIR/references/x.py"
bash "\${CLAUDE_SKILL_DIR:-\$HOME/s}/lib/y.sh"
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "skilldirin: 17 \$SKILL_DIR path inside the skill PASSes" "$(row "$o" 17)" PASS

# A references/ file written relative to the skill root (issue #34
# pattern 2): the file-relative target is missing and the root-relative one
# escapes -> WARN. `../SKILL.md` exists file-relative -> still PASS.
p=$(port rootrel <<'EOF'
See [a](references/a.md).
EOF
)
mkskill "$work/port/rootrel/references/a.md" <<'EOF'
Paths below are relative to the skill root. See [y](../other/references/y.md).
EOF
o=$(sh "$here/skill_check.sh" "$p")
eq "rootrel: 17 root-relative ../ in references/ WARNs" "$(row "$o" 17)" WARN

p=$(port filerel <<'EOF'
See [a](references/a.md).
EOF
)
mkskill "$work/port/filerel/references/a.md" <<'EOF'
Back to [the entry](../SKILL.md).
EOF
o=$(sh "$here/skill_check.sh" "$p")
eq "filerel: 17 existing file-relative ../SKILL.md PASSes" "$(row "$o" 17)" PASS

p=$(port bareroot <<EOF
$fence
bash "\${CLAUDE_PLUGIN_ROOT}/lib/x.sh"
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "bareroot: 18 unguarded plugin root WARNs" "$(row "$o" 18)" WARN

p=$(port inlineroot <<'EOF'
Verify with `bash "${CLAUDE_PLUGIN_ROOT}/lib/x.sh" out.html`.
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "inlineroot: 18 an inline prose command counts too" "$(row "$o" 18)" WARN

p=$(port defaulted <<EOF
$fence
bash "\${CLAUDE_PLUGIN_ROOT:-\$HOME/p}/lib/x.sh"
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "defaulted: 18 :- default expansion PASSes" "$(row "$o" 18)" PASS

p=$(port guarded <<EOF
$fence
[ -n "\${CLAUDE_PLUGIN_ROOT:-}" ] || exit 1
bash "\$CLAUDE_PLUGIN_ROOT/lib/x.sh"
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "guarded: 18 [ -n ] guard in the same fence PASSes" "$(row "$o" 18)" PASS

# The guard may be written without braces, or unquoted inside [[ ]].
p=$(port guardedbare <<EOF
$fence
[ -n "\$CLAUDE_PLUGIN_ROOT" ] || exit 1
bash "\$CLAUDE_PLUGIN_ROOT/lib/x.sh"
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "guardedbare: 18 unbraced guard PASSes" "$(row "$o" 18)" PASS

p=$(port guardedtest <<EOF
$fence
[[ -z \$CLAUDE_PLUGIN_ROOT ]] && exit 1
bash "\$CLAUDE_PLUGIN_ROOT/lib/x.sh"
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "guardedtest: 18 unquoted [[ ]] guard PASSes" "$(row "$o" 18)" PASS

p=$(port hinted <<EOF
On any other harness, export CLAUDE_PLUGIN_ROOT first.

$fence
bash "\$CLAUDE_PLUGIN_ROOT/lib/x.sh"
$fence
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "hinted: 18 other-harness hint in the file PASSes" "$(row "$o" 18)" PASS

p=$(port prose <<'EOF'
Claude Code sets `$CLAUDE_PLUGIN_ROOT`; this skill never reads it.
EOF
)
o=$(sh "$here/skill_check.sh" "$p")
eq "prose: 18 naming the variable in prose is not a use" "$(row "$o" 18)" 'N/A'

# ---------- Check 15: literal hosts vs SKILL.md, recursive discovery ----------
# host <name> <helper-relpath> <SKILL.md body line> -- a skill that declares
# compatibility.network, ships one helper calling https://api.acme.io, and
# prints the Check 15 result.
host() {
  hd="$work/host/$1"
  mkskill "$hd/SKILL.md" <<EOF
---
name: $1
description: Host fixture.
compatibility:
  network: required
---
$3
EOF
  mkskill "$hd/$2" <<'EOF'
import requests
requests.get("https://api.acme.io/v1")
EOF
  row "$(sh "$here/skill_check.sh" "$hd/SKILL.md")" 15
}
eq "host: 15 undocumented host WARNs" "$(host undoc lib/net.py 'Calls an API.')" WARN
eq "host: 15 host named in SKILL.md PASSes" "$(host doc lib/net.py 'Calls api.acme.io.')" PASS
eq "host: 15 a longer name containing the host does not count" "$(host substr lib/net.py 'Calls xapi.acme.io.')" WARN
eq "host: 15 host in a nested package dir WARNs" "$(host nested acme/sub/constants.py 'Calls an API.')" WARN
# The tests/ copy is pruned, so only a network-free helper is left: PASS, not N/A.
mkskill "$work/host/intests/lib/ok.sh" <<'EOF'
#!/bin/sh
echo ok
EOF
eq "host: 15 host under a nested tests/ dir is ignored" "$(host intests pkg/tests/fixture.py 'Calls an API.')" PASS
# A skill dir itself named `tests` must not prune its own root (find -mindepth 1):
# without it Check 15 sees no helpers at all and returns N/A instead of WARN.
eq "host: 15 skill dir named tests still scans its own helpers" "$(host tests scripts/net.py 'Calls an API.')" WARN
mkskill "$work/host/local/SKILL.md" <<'EOF'
---
name: local
description: Loopback fixture.
compatibility:
  network: required
---
Talks to a local server.
EOF
mkskill "$work/host/local/lib/net.sh" <<'EOF'
#!/bin/sh
curl -s http://localhost:8080/ http://127.0.0.1/ https://example.com/ https://www.example.org/x
EOF
eq "host: 15 loopback/example-only hosts PASS" "$(row "$(sh "$here/skill_check.sh" "$work/host/local/SKILL.md")" 15)" PASS
mkskill "$work/host/local/lib/auth.sh" <<'EOF'
#!/bin/sh
curl -s https://bob:tok@api.acme.io/v1
EOF
case $(note "$(sh "$here/skill_check.sh" "$work/host/local/SKILL.md")" 15) in
  *bob*) no "host: 15 userinfo is stripped before the host" "user name reported as host" ;;
  *api.acme.io*) ok "host: 15 userinfo is stripped before the host" ;;
  *) no "host: 15 userinfo is stripped before the host" "api.acme.io missing" ;;
esac
rm "$work/host/local/lib/auth.sh" # back to the all-ignored fixture
mkskill "$work/host/local/lib/placeholder.sh" <<'EOF'
#!/bin/sh
# Accepts https://host/<owner>/<repo> remotes.
EOF
eq "host: 15 a dotless placeholder host is ignored" "$(row "$(sh "$here/skill_check.sh" "$work/host/local/SKILL.md")" 15)" PASS
eq "host: 15 SKILL.md naming sub.api.acme.io does not name api.acme.io" "$(host subdom lib/net.py 'Calls sub.api.acme.io only.')" WARN
eq "host: 15 a sentence-final host still counts as named" "$(host final lib/net.py 'It calls api.acme.io.')" PASS
host quoted lib/net.py 'Calls api.acme.io.' >/dev/null
mkskill "$work/host/quoted/lib/net.py" <<'EOF'
requests.get('https://api.acme.io',auth=('u@mail.acme.io','p'))
EOF
eq "host: 15 a quote ends the userinfo (no later @ swallows the host)" "$(row "$(sh "$here/skill_check.sh" "$work/host/quoted/SKILL.md")" 15)" PASS
# Unquoted delimiters end the userinfo too (#68): a delimiter right after the
# host must not let a later @ hide that host. SKILL.md names only the later
# host, so the row WARNs only if the URL's own host is reported.
host delim lib/net.py 'Calls mail.acme.io.' >/dev/null
delim() {
  mkskill "$work/host/delim/lib/net.py"
  d=$(sh "$here/skill_check.sh" "$work/host/delim/SKILL.md")
  case "$(row "$d" 15) $(note "$d" 15)" in
    WARN*api.acme.io*) ok "$1" ;;
    *) no "$1" "api.acme.io not reported" ;;
  esac
}
delim "host: 15 a comma ends the userinfo (no later @ hides the host)" <<'EOF'
curl https://api.acme.io,u@mail.acme.io
EOF
delim "host: 15 a backtick ends the userinfo (no later @ hides the host)" <<'EOF'
echo `https://api.acme.io``u@mail.acme.io`
EOF
delim "host: 15 a > ends the userinfo (no later @ hides the host)" <<'EOF'
print("https://api.acme.io>u@mail.acme.io")
EOF
delim "host: 15 a backslash ends the userinfo (no later @ hides the host)" <<'EOF'
print("https://api.acme.io\nu@mail.acme.io")
EOF
delim "host: 15 an & ends the userinfo (no later @ hides the host)" <<'EOF'
curl https://api.acme.io&u@mail.acme.io
EOF
delim "host: 15 an = ends the userinfo (no later @ hides the host)" <<'EOF'
curl https://api.acme.io=u@mail.acme.io
EOF
delim "host: 15 a * ends the userinfo (no later @ hides the host)" <<'EOF'
curl https://api.acme.io*u@mail.acme.io
EOF
delim "host: 15 a [ ends the userinfo (no later @ hides the host)" <<'EOF'
print("https://api.acme.io[u@mail.acme.io")
EOF
delim "host: 15 a ] ends the userinfo (no later @ hides the host)" <<'EOF'
print("https://api.acme.io]u@mail.acme.io")
EOF
delim "host: 15 a + ends the userinfo (no later @ hides the host)" <<'EOF'
print("https://api.acme.io+u@mail.acme.io")
EOF
delim "host: 15 a $ ends the userinfo (no later @ hides the host)" <<'EOF'
echo https://api.acme.io$u@mail.acme.io
EOF
delim "host: 15 a ! ends the userinfo (no later @ hides the host)" <<'EOF'
echo https://api.acme.io!u@mail.acme.io
EOF
# The other direction: pct-encoded userinfo is still skipped, so its first.last
# fragment is not reported as a host (SKILL.md names only mail.acme.io).
mkskill "$work/host/delim/lib/net.py" <<'EOF'
curl https://first.last%40co@mail.acme.io
EOF
eq "host: 15 a pct-encoded userinfo is skipped, not reported" "$(row "$(sh "$here/skill_check.sh" "$work/host/delim/SKILL.md")" 15)" PASS
# ...but RFC 3986 allows , ; ( ) in userinfo, so the host after such a
# userinfo is still checked (claude review, PR #78 BLOCKER).
mkskill "$work/host/quoted/lib/net.py" <<'EOF'
requests.get("https://u,p@evil.acme.io")
EOF
d=$(sh "$here/skill_check.sh" "$work/host/quoted/SKILL.md")
case "$(row "$d" 15) $(note "$d" 15)" in
  WARN*evil.acme.io*) ok "host: 15 host after a userinfo holding a comma is still checked" ;;
  *) no "host: 15 host after a userinfo holding a comma is still checked" "evil.acme.io not reported" ;;
esac
# A whole <user>:<token>@ placeholder is userinfo: the host after it is still checked.
mkskill "$work/host/quoted/lib/net.py" <<'EOF'
# clone https://<user>:<token>@git.acme.io/r
EOF
eq "host: 15 host after a <user>:<token>@ placeholder is still checked" "$(row "$(sh "$here/skill_check.sh" "$work/host/quoted/SKILL.md")" 15)" WARN
mkskill "$work/host/local/lib/evil.sh" <<'EOF'
#!/bin/sh
curl -s https://127.evil.io/
EOF
eq "host: 15 a 127.-prefixed domain is not loopback" "$(row "$(sh "$here/skill_check.sh" "$work/host/local/SKILL.md")" 15)" WARN
case $(note "$(sh "$here/skill_check.sh" "$work/host/undoc/SKILL.md")" 15) in
  *"api.acme.io (lib/net.py)"*) ok "host: 15 note names the undeclared host and its helper file" ;;
  *) no "host: 15 note names the undeclared host and its helper file" "missing api.acme.io (lib/net.py)" ;;
esac
# A helper that only calls sub.api.acme.io (named in SKILL.md) or carries
# api.acme.io as a path segment sorts first but must not be blamed for
# api.acme.io: attribution matches the whole URL host.
host attr lib/net.py 'Calls sub.api.acme.io.' >/dev/null
mkskill "$work/host/attr/lib/a.sh" <<'EOF'
#!/bin/sh
curl -s https://sub.api.acme.io/v1 https://cdn.example.com/api.acme.io/x
EOF
case $(note "$(sh "$here/skill_check.sh" "$work/host/attr/SKILL.md")" 15) in
  *"api.acme.io (lib/net.py)"*) ok "host: 15 note blames the helper with the exact host, not a subdomain" ;;
  *) no "host: 15 note blames the helper with the exact host, not a subdomain" "expected api.acme.io (lib/net.py)" ;;
esac
ln -s "$work/host/undoc" "$work/host/undoc-link"
eq "host: 15 a symlinked skill dir is still scanned" "$(row "$(sh "$here/skill_check.sh" "$work/host/undoc-link/SKILL.md")" 15)" WARN
# Issue #85: a helper path with a space is still scanned (newline-split, not word-split).
eq "host: 15 helper in a spaced path still WARNs" "$(host spaced 'acme/my pkg/net.py' 'Calls an API.')" WARN
case $(note "$(sh "$here/skill_check.sh" "$work/host/spaced/SKILL.md")" 15) in
  *"api.acme.io (acme/my pkg/net.py)"*) ok "host: 15 note names the spaced helper path" ;;
  *) no "host: 15 note names the spaced helper path" "missing api.acme.io (acme/my pkg/net.py)" ;;
esac
# A spaced path under lib/ also reaches Checks 17/18's $port_files: the
# word-split fragment `lib/my` once made awk fail and the whole report abort.
host spacedlib 'lib/my pkg/net.py' 'Calls an API.' >/dev/null
o=$(sh "$here/skill_check.sh" "$work/host/spacedlib/SKILL.md")
case "$(row "$o" 15) $(note "$o" 15)" in
  WARN*"api.acme.io (lib/my pkg/net.py)"*) ok "host: 15 helper in a spaced lib/ path is scanned" ;;
  *) no "host: 15 helper in a spaced lib/ path is scanned" "$(row "$o" 15) $(note "$o" 15)" ;;
esac
eq "host: 17 a spaced lib/ path still yields a Check 17 row" "$(row "$o" 17)" PASS
eq "host: 18 a spaced lib/ path still yields a Check 18 row" "$(row "$o" 18)" 'N/A'
# ...and a spaced path under references/ reaches Check 11's $scan_files: an
# emoji there was silently skipped (false PASS), not counted.
mkskill "$work/host/spacedlib/references/my notes.md" <<EOF
Party $emoji here.
EOF
eq "host: 11 emoji in a spaced references/ path is counted" "$(row "$(sh "$here/skill_check.sh" "$work/host/spacedlib/SKILL.md")" 11)" FAIL
# Issue #85: an underscore in a host does not truncate it to a dotless prefix.
host under lib/net.py 'Calls an API.' >/dev/null
mkskill "$work/host/under/lib/net.py" <<'EOF'
import requests
requests.get("https://my_svc.acme.io/x")
EOF
d=$(sh "$here/skill_check.sh" "$work/host/under/SKILL.md")
case "$(row "$d" 15) $(note "$d" 15)" in
  WARN*"my_svc.acme.io (lib/net.py)"*) ok "host: 15 a host with an underscore is checked whole" ;;
  *) no "host: 15 a host with an underscore is checked whole" "my_svc.acme.io (lib/net.py) not reported" ;;
esac
printf 'Calls my_svc.acme.io.\n' >> "$work/host/under/SKILL.md"
eq "host: 15 SKILL.md naming an underscore host PASSes" "$(row "$(sh "$here/skill_check.sh" "$work/host/under/SKILL.md")" 15)" PASS
# ...and in a helper, emphasis around a URL must not glue `_` onto its host.
host emphurl lib/net.py 'Calls an API.' >/dev/null
mkskill "$work/host/emphurl/lib/net.py" <<'EOF'
# see _https://api.acme.io_ for the schema
EOF
d=$(sh "$here/skill_check.sh" "$work/host/emphurl/SKILL.md")
case "$(row "$d" 15) $(note "$d" 15)" in
  *"acme.io_"*) no "host: 15 a trailing emphasis underscore is not part of the host" "$(note "$d" 15)" ;;
  WARN*"api.acme.io (lib/net.py)"*) ok "host: 15 a trailing emphasis underscore is not part of the host" ;;
  *) no "host: 15 a trailing emphasis underscore is not part of the host" "$(row "$d" 15) $(note "$d" 15)" ;;
esac
# Markdown emphasis wraps a token in underscores that are not part of the host.
eq "host: 15 SKILL.md naming the host in _emphasis_ PASSes" "$(host emph lib/net.py 'Calls _api.acme.io_ for data.')" PASS
eq "host: 15 SKILL.md naming the host in __strong__ PASSes" "$(host strong lib/net.py 'Calls __api.acme.io__ for data.')" PASS
# ---------- issue #87: scan hardening ----------
# Finding 4: a *selfcheck* fixture is excluded from Check 15 like *selftest*,
# so its only helper being one leaves no helpers at all.
eq "i87: 15 a selfcheck fixture URL is ignored" "$(host selfck lib/net.selfcheck.sh 'Calls an API.')" 'N/A'
# Finding 5: an ellipsis after a helper host is not part of the host.
mkskill "$work/host/ellip/SKILL.md" <<'EOF'
---
name: ellip
description: Host fixture.
compatibility:
  network: required
---
Calls api.acme.io for data.
EOF
mkskill "$work/host/ellip/lib/net.sh" <<'EOF'
#!/bin/sh
# see https://api.acme.io... for the schema
curl -s "$1"
EOF
eq "i87: 15 host... matches the host SKILL.md names" "$(row "$(sh "$here/skill_check.sh" "$work/host/ellip/SKILL.md")" 15)" PASS
sed 's/Calls api.acme.io for data./Calls an API./' "$work/host/ellip/SKILL.md" > "$work/host/ellip/SKILL.md.new"
mv "$work/host/ellip/SKILL.md.new" "$work/host/ellip/SKILL.md"
o=$(sh "$here/skill_check.sh" "$work/host/ellip/SKILL.md")
case $(note "$o" 15) in
  *"api.acme.io (lib/net.sh)"*) ok "i87: 15 an undeclared host... is named without its dots" ;;
  *) no "i87: 15 an undeclared host... is named without its dots" "$(note "$o" 15)" ;;
esac
# Finding 6: the Check 17/18 scan set is recursive, as Check 15's is -- a
# helper at <pkg>/run.sh is part of the bundle; a tests/ copy is still pruned.
p=$(port nestedpkg <<'EOF'
Nothing to see here.
EOF
)
mkskill "$work/port/nestedpkg/pkg/run.sh" <<'EOF'
#!/bin/sh
. ../../shared/common.sh
EOF
mkskill "$work/port/nestedpkg/pkg/tests/fixture.sh" <<'EOF'
#!/bin/sh
bash ../../../../outside.sh
EOF
o=$(sh "$here/skill_check.sh" "$p")
eq "i87: 17 a nested helper's escape WARNs" "$(row "$o" 17)" WARN
case $(note "$o" 17) in
  *'pkg/run.sh:2 -> ../../shared/common.sh'*) ok "i87: 17 note names the nested helper" ;;
  *) no "i87: 17 note names the nested helper" "$(note "$o" 17)" ;;
esac
case $(note "$o" 17) in
  *outside.sh*) no "i87: 17 a pruned tests/ dir stays out of the scan set" "$(note "$o" 17)" ;;
  *) ok "i87: 17 a pruned tests/ dir stays out of the scan set" ;;
esac
# Finding 1: an unreadable subdir must not abort the audit -- every
# mechanical row still prints. (Root reads through mode 000, so skip there.)
if [ "$(id -u)" -ne 0 ]; then
  ur="$work/unread"
  mkskill "$ur/SKILL.md" <<'EOF'
---
name: unread
description: Unreadable subdir fixture.
---
Body.
EOF
  mkskill "$ur/lib/ok.sh" <<'EOF'
#!/bin/sh
echo ok
EOF
  mkdir -p "$ur/build/x"
  rows() { printf '%s\n' "$1" | awk -F'\t' '$1 ~ /^[0-9]+$/ { printf "%s ", $1 }'; }
  want=$(rows "$(sh "$here/skill_check.sh" "$ur/SKILL.md")")
  chmod 000 "$ur/build"
  set +e
  o=$(sh "$here/skill_check.sh" "$ur/SKILL.md" 2>/dev/null)
  rc=$?
  set -e
  chmod 755 "$ur/build"
  eq "i87: unreadable subdir does not abort (exit 0)" "$rc" 0
  # Compared with the same fixture while readable, so a new check needs no edit here.
  eq "i87: unreadable subdir still prints every mechanical row" "$(rows "$o")" "$want"
fi
# ---------- issue #77: symlinked dirs inside a skill are reported, not followed ----------
mkskill "$work/lnk/shared/refs/a.md" <<EOF
Party $emoji here.
EOF
mkskill "$work/lnk/shared/lib/net.py" <<'EOF'
import requests
requests.get("https://api.acme.io/v1")
EOF
mkskill "$work/lnk/shared/scripts/run.sh" <<'EOF'
#!/bin/sh
echo hi
EOF
for k in reflink liblink scrlink; do
  mkskill "$work/lnk/$k/SKILL.md" <<EOF
---
name: $k
description: Symlinked-dir fixture.
compatibility:
  network: required
---
Calls nothing named here.
EOF
done
ln -s ../shared/refs "$work/lnk/reflink/references"
ln -s ../shared/lib "$work/lnk/liblink/lib"
mkdir -p "$work/lnk/scrlink/lib"
ln -s ../../shared/scripts "$work/lnk/scrlink/lib/scripts"
ln -s ../shared/scripts "$work/lnk/scrlink/scripts"
o=$(sh "$here/skill_check.sh" "$work/lnk/reflink/SKILL.md")
eq "lnk: 11 symlinked references/ is WARN, not a silent PASS" "$(row "$o" 11)" WARN
case $(note "$o" 11) in
  *'not followed'*references*) ok "lnk: 11 note names the skipped references link" ;;
  *) no "lnk: 11 note names the skipped references link" "$(note "$o" 11)" ;;
esac
o=$(sh "$here/skill_check.sh" "$work/lnk/liblink/SKILL.md")
eq "lnk: 15 symlinked lib/ (its helpers unscanned) WARNs, not N/A" "$(row "$o" 15)" WARN
case $(note "$o" 15) in
  *'not followed'*lib*) ok "lnk: 15 note names the skipped lib link" ;;
  *) no "lnk: 15 note names the skipped lib link" "$(note "$o" 15)" ;;
esac
o=$(sh "$here/skill_check.sh" "$work/lnk/scrlink/SKILL.md")
case $(note "$o" 17) in
  *'not followed'*'lib/scripts, scripts'*) ok "lnk: 17 note names the skipped scripts links (top-level and nested)" ;;
  *) no "lnk: 17 note names the skipped scripts links (top-level and nested)" "$(note "$o" 17)" ;;
esac
eq "lnk: 17 symlinked scripts/ is not a silent PASS" "$(row "$o" 17)" WARN
eq "lnk: 18 symlinked scripts/ is not a silent N/A" "$(row "$o" 18)" WARN
eq "lnk: 11 a skill with no symlinked dir is untouched" "$(row "$(sh "$here/skill_check.sh" "$good")" 11)" PASS
# An allowlisted skill stays N/A (emoji there could not FAIL it), note only.
mkskill "$work/lnk/al/.claude-plugin/plugin.json" <<'EOF'
{"name": "gh-pr"}
EOF
mkskill "$work/lnk/al/approve/SKILL.md" <<EOF
---
name: approve
description: Allowlisted fixture $emoji
---
EOF
ln -s ../../shared/refs "$work/lnk/al/approve/references"
o=$(sh "$here/skill_check.sh" "$work/lnk/al/approve/SKILL.md")
eq "lnk: 11 allowlisted skill with a symlinked references/ stays N/A" "$(row "$o" 11)" 'N/A'
case $(note "$o" 11) in
  *'not followed'*references*) ok "lnk: 11 allowlisted note still names the link" ;;
  *) no "lnk: 11 allowlisted note still names the link" "$(note "$o" 11)" ;;
esac
# A link back inside a dir the scan walks, a link under a pruned name and a
# dangling link are all silent: Check 15/17/18 stay at their link-free result.
mkskill "$work/lnk/quiet/SKILL.md" <<'EOF'
---
name: quiet
description: Quiet-link fixture.
---
EOF
mkskill "$work/lnk/quiet/lib/v2/run.sh" <<'EOF'
#!/bin/sh
echo hi
EOF
ln -s v2 "$work/lnk/quiet/lib/current"
ln -s ../lib "$work/lnk/quiet/lib/v2/up"
ln -s ../missing "$work/lnk/quiet/lib/dangling"
o=$(sh "$here/skill_check.sh" "$work/lnk/quiet/SKILL.md")
eq "lnk: 15 links inside the skill / dangling stay silent" "$(row "$o" 15)" PASS
eq "lnk: 17 links inside the skill / dangling stay silent" "$(row "$o" 17)" PASS
eq "lnk: 18 links inside the skill / dangling stay silent" "$(row "$o" 18)" 'N/A'
# Checks 15 and 17/18 share one prune list (issue #87): node_modules/ is
# pruned before the link test, so the link itself is never met.
ln -s ../../shared/lib "$work/lnk/quiet/node_modules"
o=$(sh "$here/skill_check.sh" "$work/lnk/quiet/SKILL.md")
eq "lnk: 15 a link under a pruned name stays silent" "$(row "$o" 15)" PASS
eq "lnk: 17 a link under a pruned name stays silent" "$(row "$o" 17)" PASS
# A link INTO a pruned dir is not "already scanned": the scan never read its
# target, so it is reported even though the target lies inside the skill.
mkskill "$work/lnk/intotests/SKILL.md" <<'EOF'
---
name: intotests
description: Link-into-pruned-dir fixture.
---
EOF
mkskill "$work/lnk/intotests/tests/fx/run.sh" <<'EOF'
#!/bin/sh
echo hi
EOF
mkdir -p "$work/lnk/intotests/lib"
ln -s ../tests/fx "$work/lnk/intotests/lib/fx"
o=$(sh "$here/skill_check.sh" "$work/lnk/intotests/SKILL.md")
eq "lnk: 15 a link into a pruned tests/ dir WARNs" "$(row "$o" 15)" WARN
eq "lnk: 17 a link into a pruned tests/ dir WARNs" "$(row "$o" 17)" WARN
case $(note "$o" 17) in
  *'not followed'*'lib/fx'*) ok "lnk: 17 note names the link into tests/" ;;
  *) no "lnk: 17 note names the link into tests/" "$(note "$o" 17)" ;;
esac
# ---------- issue #98: symlinked FILES are reported too, not followed ----------
# A link to a regular file the check's own name filter selects is named, its
# target unread; a non-matching one (assets/logo.png for Check 15) is not.
mkskill "$work/flnk/shared/net.py" <<'EOF'
import requests
requests.get("https://api.acme.io/v1")
EOF
mkskill "$work/flnk/shared/x.md" <<EOF
Party $emoji here.
EOF
printf 'PNG' > "$work/flnk/shared/logo.png"
for k in pylink mdlink pnglink; do
  mkskill "$work/flnk/$k/SKILL.md" <<EOF
---
name: $k
description: Symlinked-file fixture.
---
Plain body.
EOF
done
mkdir -p "$work/flnk/pylink/lib" "$work/flnk/mdlink/references" "$work/flnk/pnglink/assets"
ln -s ../../shared/net.py "$work/flnk/pylink/lib/net.py"
ln -s ../../shared/x.md "$work/flnk/mdlink/references/x.md"
ln -s ../../shared/logo.png "$work/flnk/pnglink/assets/logo.png"
o=$(sh "$here/skill_check.sh" "$work/flnk/pylink/SKILL.md")
eq "flnk: 15 symlinked lib/net.py (undeclared host unread) is WARN" "$(row "$o" 15)" WARN
case $(note "$o" 15) in
  *'not followed'*'lib/net.py'*) ok "flnk: 15 note names lib/net.py" ;;
  *) no "flnk: 15 note names lib/net.py" "$(note "$o" 15)" ;;
esac
o=$(sh "$here/skill_check.sh" "$work/flnk/mdlink/SKILL.md")
eq "flnk: 11 symlinked references/x.md is WARN, not a silent PASS" "$(row "$o" 11)" WARN
case $(note "$o" 11) in
  *'not followed'*'references/x.md'*) ok "flnk: 11 note names references/x.md" ;;
  *) no "flnk: 11 note names references/x.md" "$(note "$o" 11)" ;;
esac
o=$(sh "$here/skill_check.sh" "$work/flnk/pnglink/SKILL.md")
eq "flnk: 15 a symlinked non-matching assets/logo.png leaves Check 15 unchanged" "$(row "$o" 15)" 'N/A'
case $(note "$o" 15) in
  *'not followed'*) no "flnk: 15 note does not name the png link" "$(note "$o" 15)" ;;
  *) ok "flnk: 15 note does not name the png link" ;;
esac
# Checks 17/18 select by content, which an unread target cannot show, so the
# same png link is named there (issue #98 decision: report, do not follow).
eq "flnk: 17 a symlinked assets/logo.png WARNs (target unread)" "$(row "$o" 17)" WARN
eq "flnk: 18 a symlinked assets/logo.png WARNs (target unread)" "$(row "$o" 18)" WARN
# Covered target: a file link back inside a dir the scan walks stays silent,
# through a chain of links too (alias2.sh -> alias.sh -> run.sh), as do a
# dangling link and a link loop (test -f fails on both).
mkskill "$work/flnk/quiet/SKILL.md" <<'EOF'
---
name: quiet
description: Quiet file-link fixture.
---
EOF
mkskill "$work/flnk/quiet/lib/run.sh" <<'EOF'
#!/bin/sh
echo hi
EOF
ln -s run.sh "$work/flnk/quiet/lib/alias.sh"
ln -s alias.sh "$work/flnk/quiet/lib/alias2.sh"
ln -s ../missing.sh "$work/flnk/quiet/lib/dangling.sh"
ln -s loopb.sh "$work/flnk/quiet/lib/loopa.sh"
ln -s loopa.sh "$work/flnk/quiet/lib/loopb.sh"
o=$(sh "$here/skill_check.sh" "$work/flnk/quiet/SKILL.md")
eq "flnk: 15 a file link / chain inside the skill, dangling, loop stay silent" "$(row "$o" 15)" PASS
eq "flnk: 17 a file link / chain inside the skill, dangling, loop stay silent" "$(row "$o" 17)" PASS
eq "flnk: 18 a file link / chain inside the skill, dangling, loop stay silent" "$(row "$o" 18)" 'N/A'
# A file link into a pruned dir was never read, so it is still reported.
mkskill "$work/flnk/quiet/tests/fx.sh" <<'EOF'
#!/bin/sh
echo hi
EOF
ln -s ../tests/fx.sh "$work/flnk/quiet/lib/fx.sh"
o=$(sh "$here/skill_check.sh" "$work/flnk/quiet/SKILL.md")
eq "flnk: 15 a file link into a pruned tests/ dir WARNs" "$(row "$o" 15)" WARN
case $(note "$o" 17) in
  *'not followed'*'lib/fx.sh'*) ok "flnk: 17 note names the file link into tests/" ;;
  *) no "flnk: 17 note names the file link into tests/" "$(note "$o" 17)" ;;
esac
# A target inside the skill that the check's own filter passed over was never
# read either: lib/net.py -> ../data/net.txt is unscanned by Check 15, and
# references/x.md -> notes.txt by Check 11. Checks 17/18 read both targets
# (and SKILL.md), so there the links stay silent.
mkskill "$work/flnk/filt/SKILL.md" <<'EOF'
---
name: filt
description: Filter-mismatch file-link fixture.
---
Plain body.
EOF
mkskill "$work/flnk/filt/data/net.txt" <<'EOF'
import requests
requests.get("https://api.acme.io/v1")
EOF
mkskill "$work/flnk/filt/references/notes.txt" <<EOF
Party $emoji here.
EOF
mkdir -p "$work/flnk/filt/lib"
ln -s ../data/net.txt "$work/flnk/filt/lib/net.py"
ln -s notes.txt "$work/flnk/filt/references/x.md"
ln -s ../SKILL.md "$work/flnk/filt/lib/doc.md"
o=$(sh "$here/skill_check.sh" "$work/flnk/filt/SKILL.md")
case $(note "$o" 15) in
  *'not followed'*'lib/net.py'*) ok "flnk: 15 a link to an unselected in-skill file is named" ;;
  *) no "flnk: 15 a link to an unselected in-skill file is named" "$(note "$o" 15)" ;;
esac
case $(note "$o" 11) in
  *'not followed'*'references/x.md'*) ok "flnk: 11 a link to an unselected references/ file is named" ;;
  *) no "flnk: 11 a link to an unselected references/ file is named" "$(note "$o" 11)" ;;
esac
eq "flnk: 17 links to read files (data/, references/, SKILL.md) stay silent" "$(row "$o" 17)" PASS
eq "flnk: 18 links to read files (data/, references/, SKILL.md) stay silent" "$(row "$o" 18)" 'N/A'

eq "self: 15 skill-check's git/gh helpers declare compatibility.network" "$(row "$(sh "$here/skill_check.sh" "$here/../SKILL.md")" 15)" PASS

# ---------- Check 19: eleven judged results ----------
o=$(sh "$here/skill_check.sh" "$good" PASS PASS PASS PASS PASS PASS PASS PASS PASS PASS WARN)
eq "j19: eleven-result form emits row 19" "$(row "$o" 19)" WARN
eq "j19: score counts 19 checks" "$(printf '%s\n' "$o" | awk -F'\t' '$1 == "score" { print $2 }')" 16/17
if sh "$here/skill_check.sh" "$good" $j10 >/dev/null 2>&1; then
  no "j19: ten-result form rejected" "exited 0, expected 2"
else
  rc=$?; eq "j19: ten-result form rejected (exit 2)" "$rc" 2
fi
if sh "$here/skill_check.sh" "$good" PASS PASS PASS PASS PASS PASS PASS PASS PASS PASS FAIL >/dev/null 2>&1; then
  no "j19: FAIL rejected (WARN-only)" "exited 0, expected 2"
else
  rc=$?; eq "j19: FAIL rejected (WARN-only, exit 2)" "$rc" 2
fi
# Issue #85: an empty result in the full form would drop its row yet still
# count in the denominator, so it is a usage error, not mechanical-only mode.
if sh "$here/skill_check.sh" "$good" PASS PASS PASS PASS PASS PASS PASS PASS PASS PASS '' >/dev/null 2>&1; then
  no "judgment: empty result in the full form rejected" "exited 0, expected 2"
else
  rc=$?; eq "judgment: empty result in the full form rejected (exit 2)" "$rc" 2
fi

# ---------- count drift guard ----------
# checks.md defines the checks; every place that states their count must
# agree with it (SKILL.md description, help.md, the score denominator).
skill_dir=$(cd "$here/.." && pwd)
n_defined=$(grep -cE '^### Check [0-9]+:' "$skill_dir/references/checks.md")
n_skill=$(sed -nE 's/.* on ([0-9]+) checks.*/\1/p' "$skill_dir/SKILL.md" | head -n1)
n_help=$(sed -nE 's/.*Checks run \(([0-9]+) total\).*/\1/p' "$skill_dir/references/help.md")
n_score=$(sed -nE 's/^total=\$\(\(([0-9]+) - na\)\)$/\1/p' "$here/skill_check.sh")
eq "drift: SKILL.md description count = checks.md" "$n_skill" "$n_defined"
eq "drift: help.md count = checks.md" "$n_help" "$n_defined"
eq "drift: score denominator = checks.md" "$n_score" "$n_defined"
# Judgment arity (issue #85): the usage line's j-list, the full-form `$# -eq`
# arity and checks.md's mechanical-check list must add up to the check count.
n_judged=$(sed -nE 's/^# Usage: skill_check\.sh <SKILL\.md-path> \[(j[0-9 j]*)\]$/\1/p' "$here/skill_check.sh" | wc -w | tr -d ' ')
n_arity=$(sed -nE 's/^if \[ "\$#" -eq ([0-9]+) \]; then$/\1/p' "$here/skill_check.sh" | head -n1)
n_mech=$(tr '\n' ' ' < "$skill_dir/references/checks.md" | sed -nE 's/.*extracts its own [a-z]+ mechanical checks \(([^)]*)\).*/\1/p' | grep -oE '[0-9]+' | wc -l | tr -d ' ')
eq "drift: full-form arity = 1 + judged checks" "$n_arity" "$((n_judged + 1))"
if [ "$n_mech" -gt 0 ]; then
  eq "drift: judged + mechanical checks = checks.md" "$((n_judged + n_mech))" "$n_defined"
else
  no "drift: judged + mechanical checks = checks.md" "checks.md no longer says 'extracts its own <N> mechanical checks (...)'; update the n_mech pattern"
fi
# The --help echo carries its own copy of the j-list; it must match the header.
n_usage=$(sed -nE 's/^ *echo "usage: skill_check\.sh <SKILL\.md-path> \[(j[0-9 j]*)\]"$/\1/p' "$here/skill_check.sh" | wc -w | tr -d ' ')
eq "drift: --help j-list = header j-list" "$n_usage" "$n_judged"

# ---------- mechanical-only mode: no score row without all eleven judgments ----------
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
if sh "$here/skill_check.sh" "$good" $j11 MAYBE >/dev/null 2>&1; then
  no "usage: too many judgments" "exited 0, expected 2"
else
  ok "usage: too many judgments"
fi
if sh "$here/skill_check.sh" "$work/nope.md" >/dev/null 2>&1; then
  no "usage: unreadable file" "exited 0, expected 2"
else
  ok "usage: unreadable file"
fi

# =================== skill_scan.sh / file_issue.sh (issue #89) ===================
scan="$here/skill_scan.sh"
fi_sh="$here/file_issue.sh"
# Fixture repos: no user hooks/templates, a fixed identity, and an ssh that
# always fails, so a fetch from a fake remote fails fast instead of dialing out.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_SSH_COMMAND=false
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
# parse_url reads this ssh config, not ~/.ssh/config, and asks this gh which
# hosts it is logged in to (only ghe.known.example), so no developer setup leaks in.
printf 'Host github.com\n  HostName ssh.github.com\n  Port 443\nHost github.com-work\n  HostName github.com\nHost ghe.known.example\n  HostName ssh.ghe.known.example\n' > "$work/ssh_config"
# Like real gh, the stub hands an env token out for any host name.
cat > "$work/gh-hosts" <<'EOF'
#!/bin/sh
[ -n "$GH_TOKEN$GITHUB_TOKEN$GH_ENTERPRISE_TOKEN$GITHUB_ENTERPRISE_TOKEN" ] ||
  [ "$*" = "auth token --hostname ghe.known.example" ]
EOF
chmod +x "$work/gh-hosts"
export SKILL_CHECK_SSH_CONFIG="$work/ssh_config" SKILL_CHECK_GH="$work/gh-hosts"
# rc <cmd...> -- exit status of a command, never tripping set -e.
rc() { "$@" >/dev/null 2>&1 && echo 0 || echo $?; }
# repo <dir> [remote url]... -- git repo with one commit holding skills/s/SKILL.md.
repo() {
  d=$1; shift
  mkskill "$d/skills/s/SKILL.md" <<'EOF'
---
name: s
description: Scan fixture.
---
EOF
  git init -q -b main "$d"
  git -C "$d" add -A
  git -C "$d" commit -q -m init
  while [ $# -gt 0 ]; do git -C "$d" remote add "$1" "$2"; shift 2; done
}
col() { printf '%s\n' "$1" | awk -F'\t' -v c="$2" 'NR == 1 { print $c }'; }

# ---------- parse-url: three accepted forms ----------
eq "scan: parse git@ form" "$(sh "$scan" parse-url git@ghe.example.com:o/r.git)" "$(printf 'ghe.example.com\to/r')"
eq "scan: parse ssh:// form" "$(sh "$scan" parse-url ssh://git@ghe.example.com:2222/o/r)" "$(printf 'ghe.example.com\to/r')"
eq "scan: parse https form" "$(sh "$scan" parse-url https://example.com/o/r.git)" "$(printf 'example.com\to/r')"
# issue #91: HostName replaces only an alias, never a host gh already knows.
eq "scan: github.com kept despite HostName ssh.github.com" "$(sh "$scan" parse-url git@github.com:o/r.git)" "$(printf 'github.com\to/r')"
eq "scan: ssh alias resolves to its HostName" "$(sh "$scan" parse-url git@github.com-work:o/r)" "$(printf 'github.com\to/r')"
eq "scan: gh-logged-in host kept despite HostName" "$(sh "$scan" parse-url ssh://git@ghe.known.example/o/r)" "$(printf 'ghe.known.example\to/r')"
for v in GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN; do
  eq "scan: $v does not hide an alias" "$(env "$v=x" sh "$scan" parse-url git@github.com-work:o/r)" "$(printf 'github.com\to/r')"
done
eq "scan: alias resolves when gh is missing" "$(SKILL_CHECK_GH="$work/no-gh" sh "$scan" parse-url git@github.com-work:o/r)" "$(printf 'github.com\to/r')"
eq "scan: parse rejects a host that reads as an option" "$(rc sh "$scan" parse-url git@-oFoo:o/r)" 2
eq "scan: parse rejects a local path" "$(rc sh "$scan" parse-url /srv/git/r.git)" 2

# ---------- issue target: upstream first, origin fallback, none ----------
repo "$work/t/both" origin git@example.com:me/fork.git upstream https://example.com/up/main.git
repo "$work/t/orig" origin git@example.com:me/only.git
repo "$work/t/none"
o=$(sh "$scan" scan dir "$work/t/both")
eq "scan: upstream wins over origin" "$(col "$o" 4) $(col "$o" 5)" "up/main upstream"
o=$(sh "$scan" scan dir "$work/t/orig")
eq "scan: origin when no upstream" "$(col "$o" 4) $(col "$o" 5)" "me/only origin"
o=$(sh "$scan" scan dir "$work/t/none")
eq "scan: no remote -> target none" "$(col "$o" 5) $(col "$o" 6)" "none worktree"

# ---------- -R: DUP for a second checkout of the same target ----------
repo "$work/R/alpha" origin git@example.com:o/alpha.git
git -C "$work/R/alpha" worktree add -q "$work/R/alpha-claude-1" 2>/dev/null
repo "$work/R/beta" origin git@example.com:o/beta.git
mkdir -p "$work/R/not-a-repo/skills/x" && echo x > "$work/R/not-a-repo/skills/x/SKILL.md"
o=$(sh "$scan" scan recursive "$work/R")
eq "scan: -R the worktree is DUP of the main checkout" \
  "$(printf '%s\n' "$o" | awk -F'\t' '$5 == "dup" { print $6 }')" "same target as alpha/"
eq "scan: -R audits each distinct repo once" \
  "$(printf '%s\n' "$o" | awk -F'\t' '$2 != "-"' | wc -l | tr -d ' ')" 2
eq "scan: -R skips a non-repo child" "$(printf '%s\n' "$o" | grep -c not-a-repo || true)" 0

# ---------- discovery prune ----------
p="$work/prune"
for f in skills/a .claude/worktrees/w/skills/a .worktrees/w/skills/a tests/x fixtures/x vendor/x node_modules/x; do
  mkskill "$p/$f/SKILL.md" </dev/null
done
o=$(sh "$scan" scan dir "$p")
eq "scan: prune keeps only skills/a" "$(printf '%s\n' "$o" | cut -f2 | sed "s|^$(cd -P "$p" && pwd -P)/||")" "skills/a/SKILL.md"

# ---------- dedup key ----------
mkskill "$work/t/orig/.claude-plugin/plugin.json" <<'EOF'
{"name": "plug"}
EOF
eq "key: <plugin>:<skill> with a manifest" "$(sh "$scan" key "$work/t/orig/skills/s/SKILL.md")" "plug:s"
eq "key: bare <skill> without one" "$(sh "$scan" key "$work/t/none/skills/s/SKILL.md")" "s"

# ---------- snapshot: a dirty feature branch never reaches the issue ----------
git init -q --bare -b main "$work/snap/up.git"
repo "$work/snap/local" upstream "$work/snap/up.git"
# export-ignore must not strip the snapshot (git archive would honour it).
mkskill "$work/snap/local/skills/s/references/r.md" </dev/null
printf 'skills/s/references export-ignore\n' > "$work/snap/local/.gitattributes"
git -C "$work/snap/local" add -A
git -C "$work/snap/local" commit -q -m refs
git -C "$work/snap/local" push -q upstream main
git -C "$work/snap/local" fetch -q upstream
git -C "$work/snap/local" remote set-head upstream main
# Now point upstream at a URL that parses but cannot be fetched (ssh=false):
# the scan must fall back to the existing remote-tracking ref and flag it.
git -C "$work/snap/local" remote set-url upstream git@example.com:up/local.git
git -C "$work/snap/local" checkout -q -b feat
echo 'LOCAL-ONLY committed' >> "$work/snap/local/skills/s/SKILL.md"
git -C "$work/snap/local" commit -q -am feat
echo 'LOCAL-ONLY dirty' >> "$work/snap/local/skills/s/SKILL.md"
st=$(mktemp -d "$work/st.XXXXXX")
o=$(sh "$scan" scan dir "$work/snap/local" --snapshot --tmp "$st" 2>/dev/null)
eq "snapshot: target is upstream" "$(col "$o" 4) $(col "$o" 5)" "up/local upstream"
case $(col "$o" 6) in "upstream/main@"*" stale:"*) ok "snapshot: stale ref flagged" ;; *) no "snapshot: stale ref flagged" "got [$(col "$o" 6)]" ;; esac
eq "snapshot: audited file is the default-branch copy" "$(grep -c LOCAL-ONLY "$(col "$o" 2)" || true)" 0
eq "snapshot: working tree untouched" "$(grep -c LOCAL-ONLY "$work/snap/local/skills/s/SKILL.md")" 2
o=$(sh "$scan" scan single "$work/snap/local/skills/s/SKILL.md" --snapshot --tmp "$st" 2>/dev/null)
eq "snapshot: single mode maps into the snapshot" "$(grep -c LOCAL-ONLY "$(col "$o" 2)" || true)" 0
eq "snapshot: export-ignore paths are kept" "$(test -f "$(dirname "$(col "$o" 2)")/references/r.md" && echo yes)" yes
# No manifest in the repo: the key walk-up stops at the snapshot root.
eq "snapshot: key walk-up stops at the snapshot root" "$(sh "$scan" key "$(col "$o" 2)")" s
eq "snapshot: --snapshot without --tmp is usage" "$(rc sh "$scan" scan dir "$work/snap/local" --snapshot)" 2
mkskill "$work/snap/local/extra/skills/e/SKILL.md" </dev/null
o=$(sh "$scan" scan dir "$work/snap/local/extra" --snapshot --tmp "$st" 2>/dev/null)
eq "snapshot: a dir missing from the default branch is a skip row" "$(col "$o" 2) $(col "$o" 5)" "- skip"

# ---------- -r on a fork: --snapshot clones the parent (the issue target) ----------
fk="$work/fork"
repo "$fk/src"
git init -q --bare -b main "$fk/up/r.git"
git -C "$fk/src" push -q "$fk/up/r.git" main
echo 'FORK-ONLY' >> "$fk/src/skills/s/SKILL.md"
git -C "$fk/src" commit -q -am fork
git init -q --bare -b main "$fk/me/r.git"
git -C "$fk/src" push -q "$fk/me/r.git" main
printf '#!/bin/sh\necho up/r\n' > "$fk/gh"; chmod +x "$fk/gh"
# insteadOf maps the https URLs onto the local bare repos: no network.
fork_scan() {
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$fk/.insteadOf" GIT_CONFIG_VALUE_0=https://example.com/ \
    SKILL_CHECK_GH="$fk/gh" sh "$scan" scan repo https://example.com/me/r.git --tmp "$st" "$@" 2>/dev/null
}
o=$(fork_scan --snapshot)
eq "repo: a fork's issue target is its parent" "$(col "$o" 4) $(col "$o" 5)" "up/r fork-parent"
eq "repo: --snapshot audits the parent, not the fork" "$(grep -c FORK-ONLY "$(col "$o" 2)" || true)" 0
o=$(fork_scan)
eq "repo: without --snapshot the given fork is audited" "$(grep -c FORK-ONLY "$(col "$o" 2)" || true)" 1

# ---------- args ----------
eq "args: single defaults issue off" "$(sh "$scan" args x)" "$(printf 'single\tx\toff\t0\t0')"
eq "args: batch defaults issue on" "$(sh "$scan" args -d "$p" -y)" "$(printf 'dir\t%s\ton\t1\t0' "$p")"
eq "args: --no-issue turns batch off" "$(sh "$scan" args -R "$work/R" --no-issue | cut -f3)" off
eq "args: --deep-subskills" "$(sh "$scan" args x --deep-subskills | cut -f5)" 1
eq "args: two modes" "$(rc sh "$scan" args x -d "$p")" 2
eq "args: --issue with --no-issue" "$(rc sh "$scan" args --issue --no-issue)" 2
eq "args: -d without a value" "$(rc sh "$scan" args -d)" 2
eq "args: -r with a non-URL" "$(rc sh "$scan" args -r /srv/r)" 2
eq "args: unknown option" "$(rc sh "$scan" args --bogus)" 2
case $(sh "$scan" args "$good" --recursive 2>&1 || true) in
  *--deep-subskills*) ok "args: old <path> --recursive names the migration" ;;
  *) no "args: old <path> --recursive names the migration" "no --deep-subskills hint" ;;
esac
eq "args: old <path> --recursive exits 2" "$(rc sh "$scan" args "$good" --recursive)" 2
eq "args: --recursive <file> exits 2" "$(rc sh "$scan" args --recursive "$good")" 2
eq "args: --recursive <skill dir> exits 2" "$(rc sh "$scan" args --recursive "$(dirname "$good")")" 2

# ---------- resolve: path, local checkout, installed plugin, flat link ----------
rs="$work/res"
repo "$rs/cwd/p1"; mkskill "$rs/cwd/p1/.claude-plugin/plugin.json" <<'EOF'
{"name": "alpha"}
EOF
mkskill "$rs/cwd/p1/skills/dup/SKILL.md" </dev/null
repo "$rs/cwd/p2"; mkskill "$rs/cwd/p2/.claude-plugin/plugin.json" <<'EOF'
{"name": "beta"}
EOF
mkskill "$rs/cwd/p2/skills/dup/SKILL.md" </dev/null
mkskill "$rs/inst/gamma/skills/bar/SKILL.md" </dev/null
mkskill "$rs/home/.claude/plugins/installed_plugins.json" <<EOF
{
  "version": 2,
  "plugins": {
    "gamma@market": [
      { "scope": "user", "installPath": "$rs/inst/gamma", "version": "1.0.0" }
    ]
  }
}
EOF
mkskill "$rs/home/.claude/skills/baz/SKILL.md" </dev/null
in_rs() { (cd "$rs/cwd" && HOME="$rs/home" CLAUDE_CONFIG_DIR="$rs/home/.claude" "$@"); }
res() { in_rs sh "$scan" resolve "$1" 2>/dev/null | sed "s|^$(cd -P "$rs" && pwd -P)/||"; }
eq "resolve: plugin:skill from a local checkout" "$(res alpha:s)" "cwd/p1/skills/s/SKILL.md"
eq "resolve: leading slash dropped" "$(res /beta:dup)" "cwd/p2/skills/dup/SKILL.md"
eq "resolve: bare name, distinct plugins -> ambiguous" "$(rc in_rs sh "$scan" resolve dup)" 2
eq "resolve: installed plugin" "$(res gamma:bar)" "inst/gamma/skills/bar/SKILL.md"
eq "resolve: bare name in an installed plugin" "$(res bar)" "inst/gamma/skills/bar/SKILL.md"
eq "resolve: flat skill link" "$(res baz)" "home/.claude/skills/baz/SKILL.md"
eq "resolve: a directory means its SKILL.md" "$(res "$rs/cwd/p1/skills/s")" "cwd/p1/skills/s/SKILL.md"
eq "resolve: unknown name" "$(rc in_rs sh "$scan" resolve nope)" 2
# Two checkouts of one manifest-less repo are one candidate, not ambiguous.
repo "$rs/cwd/p3" origin git@example.com:o/p3.git
mkskill "$rs/cwd/p3/skills/solo/SKILL.md" </dev/null
git -C "$rs/cwd/p3" add -A && git -C "$rs/cwd/p3" commit -q -m solo
git -C "$rs/cwd/p3" worktree add -q "$rs/cwd/p3-claude-1" 2>/dev/null
eq "resolve: worktree of a manifest-less repo is not ambiguous" "$(res solo)" "cwd/p3/skills/solo/SKILL.md"

# ---------- key matches Check 11's allowlist key (two copies of one rule) ----------
mkskill "$work/k/.claude-plugin/plugin.json" <<'EOF'
{"name": "kp"}
EOF
mkskill "$work/k/skills/ks/SKILL.md" <<EOF
---
name: ks
description: Key fixture $emoji
---
EOF
eq "key: same key as skill_check.sh Check 11" "$(sh "$scan" key "$work/k/skills/ks/SKILL.md")" \
  "$(note "$(sh "$here/skill_check.sh" "$work/k/skills/ks/SKILL.md")" 11 | sed -n "s/.*key '\([^']*\)'.*/\1/p")"

# ---------- file_issue.sh against a stub gh ----------
stub="$work/stub"; mkdir -p "$stub"
cat > "$stub/gh" <<'EOF'
#!/bin/sh
# Stub gh: answers only what file_issue.sh asks. State lives in $STUB.
case "$1 $2" in
  "auth status") [ ! -f "$STUB/noauth" ] ;;
  "repo view") echo true ;;
  "label list") printf 'fix\nskill\n' ;;
  "issue list") cat "$STUB/open" 2>/dev/null || true ;;
  "issue create")
    printf '%s\n' "$*" > "$STUB/created"
    echo "#7 https://example.com/o/r/issues/7" > "$STUB/open"
    echo "https://example.com/o/r/issues/7" ;;
  *) echo "stub gh: unexpected $*" >&2; exit 1 ;;
esac
EOF
chmod +x "$stub/gh"
body="$work/body.md"
printf 'Findings\n\nskill-check-key: plug:s\n' > "$body"
fi_run() { STUB="$stub" SKILL_CHECK_GH="$stub/gh" sh "$fi_sh" "$@"; }
eq "file_issue: --check NEW before filing" "$(fi_run --check example.com o/r plug:s)" NEW
eq "file_issue: first run files" "$(fi_run example.com o/r plug:s 'fix(s): findings' "$body" fix,refactor,skill)" \
  "NEW #7 https://example.com/o/r/issues/7"
case $(cat "$stub/created") in
  *"--label fix --label skill"*) ok "file_issue: only existing labels applied" ;;
  *) no "file_issue: only existing labels applied" "got [$(cat "$stub/created")]" ;;
esac
eq "file_issue: second run is EXISTS" "$(fi_run example.com o/r plug:s 'fix(s): findings' "$body")" \
  "EXISTS #7 https://example.com/o/r/issues/7"
eq "file_issue: --check EXISTS after filing" "$(fi_run --check example.com o/r plug:s)" "EXISTS #7 https://example.com/o/r/issues/7"
printf 'no key line\n' > "$work/nokey.md"
eq "file_issue: body without the key line is usage" "$(rc fi_run example.com o/r plug:s t "$work/nokey.md")" 2
eq "file_issue: key with a quote is usage" "$(rc fi_run --check example.com o/r 'a"b')" 2
eq "file_issue: preflight OK" "$(fi_run --preflight example.com o/r)" OK
touch "$stub/noauth"
eq "file_issue: preflight SKIP without auth" "$(fi_run --preflight example.com o/r)" "SKIP gh not logged in to example.com"

[ "$fails" -eq 0 ] || { printf '\n%s check(s) failed\n' "$fails" >&2; exit 1; }
printf '\nall checks passed\n'
