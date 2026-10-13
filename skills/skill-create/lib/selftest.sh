#!/bin/sh
# selftest.sh -- one runnable check for scripts/quick_validate.py's
# allowed_domains shape and pairing checks (issues #69, #82) and its frontmatter key allowlist
# (issue #81). Builds throwaway skills and asserts which ones validate.
# Run: sh lib/selftest.sh

set -eu

here=$(cd "$(dirname "$0")" && pwd)
qv=$here/../scripts/quick_validate.py
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

# expect <label> <0|1> <skill-dir> [<message-substring>]
expect() {
  rc=0
  out=$(python3 "$qv" "$3" 2>&1) || rc=$?
  if [ "$rc" -ne "$2" ]; then
    printf 'FAIL %s -- exit %s, wanted %s: %s\n' "$1" "$rc" "$2" "$out"
    fails=$((fails + 1))
  elif [ -n "${4-}" ] && ! printf '%s' "$out" | grep -qF -- "$4"; then
    printf 'FAIL %s -- message lacks [%s]: %s\n' "$1" "$4" "$out"
    fails=$((fails + 1))
  else
    printf 'ok   %s\n' "$1"
  fi
}

# fixture <name> <extra frontmatter YAML line(s)> -> a minimal skill dir
fixture() {
  mkdir -p "$work/$1"
  printf -- '---\nname: demo\ndescription: Demo skill.\n%s\n---\nbody\n' "$2" > "$work/$1/SKILL.md"
  printf '%s' "$work/$1"
}

# A valid allowed_domains needs its compatibility.network pairing (issue #82).
net='compatibility: {network: required}'

expect "skill-create itself validates" 0 "$here/.."
expect "no allowed_domains is fine" 0 "$(fixture none '')"
expect "hostname list passes" 0 "$(fixture list "$net
allowed_domains: [fonts.googleapis.com, localhost]")"
expect "allowed_domains without compatibility fails" 1 "$(fixture nocompat 'allowed_domains: [x.io]')" "(no compatibility.network)"
expect "scalar fails" 1 "$(fixture scalar 'allowed_domains: fonts.gstatic.com')" "must be a list"
expect "URL fails" 1 "$(fixture url 'allowed_domains: [https://fonts.gstatic.com/css]')" "not a plain hostname"
expect "wildcard fails" 1 "$(fixture wild 'allowed_domains: ["*.x.io"]')" "not a plain hostname"
expect "port fails" 1 "$(fixture port 'allowed_domains: [example.com:443]')" "not a plain hostname"
expect "whitespace fails" 1 "$(fixture space 'allowed_domains: ["a b.io"]')" "not a plain hostname"
expect "non-string entry fails" 1 "$(fixture num 'allowed_domains: [42]')" "not a plain hostname"
label63=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
expect "63-char label passes" 0 "$(fixture l63 "$net
allowed_domains: [$label63.io]")"
expect "64-char label fails" 1 "$(fixture l64 "allowed_domains: [${label63}a.io]")" "not a plain hostname"
expect "258-char hostname fails (253 cap)" 1 "$(fixture l254 "allowed_domains: [$label63.$label63.$label63.$label63.io]")" "not a plain hostname"
expect "punycode IDN passes" 0 "$(fixture idn "$net
allowed_domains: [xn--mnchen-3ya.de]")"
expect "empty string fails" 1 "$(fixture empty 'allowed_domains: [""]')" "not a plain hostname"
expect "trailing dot fails" 1 "$(fixture dot 'allowed_domains: [example.com.]')" "not a plain hostname"
expect "leading hyphen fails" 1 "$(fixture hyph 'allowed_domains: [-a.io]')" "not a plain hostname"
expect "underscore fails" 1 "$(fixture under 'allowed_domains: [_dmarc.x.io]')" "not a plain hostname"
expect "empty list fails" 1 "$(fixture emptylist 'allowed_domains: []')" "at least one hostname"
expect "mapping compatibility with network: required passes" 0 "$(fixture netreq "$(printf 'compatibility:\n  network: required\nallowed_domains: [x.io]')")"
expect "mapping compatibility without network fails" 1 "$(fixture nonet "$(printf 'compatibility:\n  tools: [python3]\nallowed_domains: [x.io]')")" "requires compatibility.network: required"
expect "mapping compatibility with other network value fails" 1 "$(fixture netopt "$(printf 'compatibility:\n  network: optional\nallowed_domains: [x.io]')")" "got network: 'optional'"
expect "string compatibility skips pairing" 0 "$(fixture netstr "$(printf 'compatibility: needs python3\nallowed_domains: [x.io]')")"
expect "whitespace-only compatibility does not skip pairing" 1 "$(fixture netws "$(printf 'compatibility: "  "\nallowed_domains: [x.io]')")" "(no compatibility.network)"
expect "user-invocable key passes" 0 "$(fixture uinv 'user-invocable: false')"
expect "argument-hint key passes" 0 "$(fixture ahint 'argument-hint: "<n>"')"
expect "disable-model-invocation key passes" 0 "$(fixture dmi 'disable-model-invocation: true')"
expect "unknown key still fails" 1 "$(fixture unk 'bogus-key: 1')" "Unexpected key(s)"
expect "non-string key reports, not crashes" 1 "$(fixture boolkey 'on: push')" "Unexpected key(s)"
expect "quoted user-invocable fails" 1 "$(fixture uinvs 'user-invocable: "false"')" "must be an unquoted true or false"
expect "quoted disable-model-invocation fails" 1 "$(fixture dmis 'disable-model-invocation: "true"')" "must be an unquoted true or false"
expect "empty user-invocable names the empty value" 1 "$(fixture uinve 'user-invocable:')" "got an empty value"
expect "unquoted bracket argument-hint passes" 0 "$(fixture ahintl 'argument-hint: [issue-number]')"

# The allowlist must equal skill-check Check 3's "Known attributes" (issue #81
# was exactly this drift). Skipped only when skill-check is absent altogether
# (a standalone copy of skill-create); a moved or renamed checks.md fails.
checks=$here/../../skill-check/references/checks.md
if [ -d "$here/../../skill-check" ]; then
  if out=$(PYTHONPATH="$here/../scripts" python3 - "$checks" <<'EOF' 2>&1
import re, sys
from quick_validate import ALLOWED_PROPERTIES
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
start = next((i for i, l in enumerate(lines) if l.startswith("Known attributes:")), None)
if start is None:
    sys.exit("no 'Known attributes:' line in checks.md -- update this parser")
para = [lines[start]]
for l in lines[start + 1:]:
    if not l.strip() or l.startswith(("**", "#", "-", "|")):
        break
    para.append(l)
known = set(re.findall(r"`([^`]+)`", " ".join(para)))
if not known:
    sys.exit("'Known attributes:' paragraph lists no backticked keys -- update this parser")
if known != set(ALLOWED_PROPERTIES):
    sys.exit(f"Check 3 only: {sorted(known - ALLOWED_PROPERTIES)}; "
             f"quick_validate only: {sorted(ALLOWED_PROPERTIES - known)}")
EOF
  ); then
    printf 'ok   allowlist matches skill-check Check 3\n'
  else
    printf 'FAIL allowlist drifted from skill-check Check 3 -- %s\n' "$out"
    fails=$((fails + 1))
  fi
else
  printf 'skip allowlist parity (no skill-check next to skill-create)\n'
fi

if [ "$fails" -ne 0 ]; then
  printf '%s check(s) failed\n' "$fails"
  exit 1
fi
echo "all quick_validate checks passed"
