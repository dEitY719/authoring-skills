#!/bin/sh
# selftest.sh -- one runnable check for scripts/quick_validate.py's
# allowed_domains shape check (issue #69) and its frontmatter key allowlist
# (issue #81). Builds throwaway skills and asserts
# which ones validate. Run: sh lib/selftest.sh

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

# fixture <name> <allowed_domains YAML line> -> a minimal skill dir
fixture() {
  mkdir -p "$work/$1"
  printf -- '---\nname: demo\ndescription: Demo skill.\n%s\n---\nbody\n' "$2" > "$work/$1/SKILL.md"
  printf '%s' "$work/$1"
}

expect "skill-create itself validates" 0 "$here/.."
expect "no allowed_domains is fine" 0 "$(fixture none '')"
expect "hostname list passes" 0 "$(fixture list 'allowed_domains: [fonts.googleapis.com, localhost]')"
expect "scalar fails" 1 "$(fixture scalar 'allowed_domains: fonts.gstatic.com')" "must be a list"
expect "URL fails" 1 "$(fixture url 'allowed_domains: [https://fonts.gstatic.com/css]')" "not a plain hostname"
expect "wildcard fails" 1 "$(fixture wild 'allowed_domains: ["*.x.io"]')" "not a plain hostname"
expect "port fails" 1 "$(fixture port 'allowed_domains: [example.com:443]')" "not a plain hostname"
expect "whitespace fails" 1 "$(fixture space 'allowed_domains: ["a b.io"]')" "not a plain hostname"
expect "non-string entry fails" 1 "$(fixture num 'allowed_domains: [42]')" "not a plain hostname"
label63=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
expect "63-char label passes" 0 "$(fixture l63 "allowed_domains: [$label63.io]")"
expect "64-char label fails" 1 "$(fixture l64 "allowed_domains: [${label63}a.io]")" "not a plain hostname"
expect "258-char hostname fails (253 cap)" 1 "$(fixture l254 "allowed_domains: [$label63.$label63.$label63.$label63.io]")" "not a plain hostname"
expect "punycode IDN passes" 0 "$(fixture idn 'allowed_domains: [xn--mnchen-3ya.de]')"
expect "empty string fails" 1 "$(fixture empty 'allowed_domains: [""]')" "not a plain hostname"
expect "trailing dot fails" 1 "$(fixture dot 'allowed_domains: [example.com.]')" "not a plain hostname"
expect "leading hyphen fails" 1 "$(fixture hyph 'allowed_domains: [-a.io]')" "not a plain hostname"
expect "underscore fails" 1 "$(fixture under 'allowed_domains: [_dmarc.x.io]')" "not a plain hostname"
expect "user-invocable key passes" 0 "$(fixture uinv 'user-invocable: false')"
expect "argument-hint key passes" 0 "$(fixture ahint 'argument-hint: "<n>"')"
expect "disable-model-invocation key passes" 0 "$(fixture dmi 'disable-model-invocation: true')"
expect "unknown key still fails" 1 "$(fixture unk 'bogus-key: 1')" "Unexpected key(s)"

if [ "$fails" -ne 0 ]; then
  printf '%s check(s) failed\n' "$fails"
  exit 1
fi
echo "all quick_validate checks passed"
