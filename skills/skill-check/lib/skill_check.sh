#!/bin/sh
# skill_check.sh -- the mechanical half of authoring:skill-check.
#
# Usage: skill_check.sh <SKILL.md-path> [j2 j3 j4 j5 j6 j7 j8 j9 j10 j12 j19]
#   j2..j19 are the auditor's own calls for the eleven checks no grep can
#   decide -- 2 Progressive Disclosure, 3 Frontmatter Validity (naming
#   judgment), 4 References Directory Usage, 5 Output Report Defined, 6 Help
#   Flag Pattern (verbatim-ness), 7 Step Structure, 8 Options Documentation,
#   9 Verdict Output, 10 Next-action Hint, 12 Executable Procedure
#   Extraction, 19 Credential-to-Network Flow -- each PASS | WARN | FAIL |
#   N/A (19 is WARN-only: PASS | WARN | N/A), in that check-id order. Pass
#   all eleven or none. The pre-Check-19 ten-result form is rejected (exit 2)
#   rather than silently shifting each result onto the wrong check.
#
# stdout: check<TAB>result<TAB>note, one row per decided check, ascending id.
#         With the eleven judgments it also emits every row plus a final
#         score<TAB><pass>/<effective-total><TAB><VERDICT>
#         computed per references/report-template.md verdict thresholds.
# exit:   0 report written | 2 bad usage or unreadable file
#
# Read-only: never edits the audited file. Criteria: references/checks.md.
#
# ponytail: Check 16 probes `locale -a` for a real UTF-8 locale (see that
# check, below) rather than hardcoding one. If NONE is installed at all --
# rare, but possible on a minimal container -- it still falls back to
# C.utf8 and flags the result as approximate in the note rather than either
# crashing or silently mis-measuring. Upgrade path if that ever bites: shell
# out to `python3 -c` for a locale-independent length.
# ponytail: Check 13's migration-gate state (metadata absent -> FAIL) is
# hardcoded from references/model-recommendation.md Section 3's current
# MIGRATION_COMPLETE=true. If that gate ever reopens, flip GATE_FAIL below.
# ponytail: Check 11's "stale entry" / "outside audited scope" nuance
# (checks.md "Stale entries" paragraph) needs to know which repos are in
# scope for this audit run -- that judgment call stays with the auditor; this
# script only ever emits FAIL (key absent) or N/A (key present), never the
# stale-entry WARN.
# File lists ($scan_files, $scripts, $port_files) are newline-delimited and
# consumed either by a `while IFS= read -r` loop or by `IFS=<newline>; set -f;
# set -- $list` (issue #85), so a path containing a space stays one path.

set -eu

GATE_FAIL=1 # MIGRATION_COMPLETE=true -> missing metadata.model_recommendation is FAIL, not WARN

file=${1:-}

case $file in
  -h|--help|help)
    echo "usage: skill_check.sh <SKILL.md-path> [j2 j3 j4 j5 j6 j7 j8 j9 j10 j12 j19]"
    exit 0
    ;;
  '')
    echo "skill_check: missing <SKILL.md-path>" >&2
    exit 2
    ;;
esac

[ -r "$file" ] || { echo "skill_check: cannot read '$file'" >&2; exit 2; }

j2='' j3='' j4='' j5='' j6='' j7='' j8='' j9='' j10='' j12='' j19=''
if [ "$#" -eq 12 ]; then
  shift
  # An empty result would drop its row yet still count in the denominator.
  for j; do [ -n "$j" ] || { echo "skill_check: judgment results must not be empty" >&2; exit 2; }; done
  j2=$1 j3=$2 j4=$3 j5=$4 j6=$5 j7=$6 j8=$7 j9=$8 j10=$9 j12=${10} j19=${11}
elif [ "$#" -eq 11 ]; then
  echo "skill_check: got ten judgment results -- the pre-Check-19 form; append j19 (Credential-to-Network Flow) as the eleventh" >&2
  exit 2
elif [ "$#" -ne 1 ]; then
  echo "skill_check: pass the eleven judgment results (j2 j3 j4 j5 j6 j7 j8 j9 j10 j12 j19) or none" >&2
  exit 2
fi
for j in "$j2" "$j3" "$j4" "$j5" "$j6" "$j7" "$j8" "$j9" "$j10" "$j12" "$j19"; do
  case $j in
    ''|PASS|WARN|FAIL|N/A) ;;
    *) echo "skill_check: judgment must be PASS|WARN|FAIL|N/A, got '$j'" >&2; exit 2 ;;
  esac
done
[ "$j19" != FAIL ] || { echo "skill_check: Check 19 is WARN-only -- j19 must be PASS|WARN|N/A" >&2; exit 2; }

dir=$(cd "$(dirname "$file")" && pwd)
refdir="$dir/references"
# This script's OWN install directory -- distinct from $dir, the directory of
# whatever SKILL.md is being *audited*. The Check 11 allowlist is data this
# tool owns and must be read from here, never from the audited skill's own
# references/ (an audited skill self-allowlisting its own emoji would defeat
# the check entirely -- codex PR #16 BLOCKER).
tool_dir=$(cd "$(dirname "$0")" && pwd)

# find_upward <start-dir> <name>... -- print the first <start-dir>/<name>
# found while walking up parent directories, stopping at `.git` or `/`.
# `.git` is `-e`, not `-d`: a git-worktree checkout (this repo included, per
# codex PR #16 FOLLOW-UP -- confirmed empirically, this very worktree has a
# `.git` FILE pointing at the real gitdir) would otherwise walk straight past
# its own root into whatever sits above it.
# Shared by Check 11 (plugin.json) and Check 14 (LICENSE).
find_upward() {
  d=$1; shift
  while :; do
    for n in "$@"; do
      [ -f "$d/$n" ] && { printf '%s\n' "$d/$n"; return; }
    done
    [ -e "$d/.git" ] && return
    [ "$d" = / ] && return
    d=$(dirname "$d")
  done
}

# scan_tree [-H] <root> <find-expr>... -- the one file lister for Checks 11,
# 15 and 17/18 (issues #77, #98). Prints `F<TAB>path` for each regular file
# the expression selects (it must include `-type f`, and may lead with a
# `( names ) -prune -o`), and `L<TAB>path` for each link it met and did not
# follow: a symlinked directory, or a symlink to a regular file that the same
# expression would have selected were it a plain file (its `-type f` read as
# `-type l`, with a `test -f` appended after the caller's own filters, so a
# link they reject costs no process). Contract this rewrite relies on: `-type`
# appears only as a primary, and nothing is `-o`-joined after `-type f` at the
# top level (group alternatives in `( )`). Links are never followed (issue
# #32), so a scan
# reports them rather than skipping them silently. -H dereferences <root>
# only; without it a symlinked <root> is itself reported as skipped.
scan_tree() {
  st_h=''
  [ "$1" = -H ] && { st_h=-H; shift; }
  st_root=$1; shift
  if [ -z "$st_h" ] && [ -L "$st_root" ]; then
    [ -d "$st_root" ] && printf 'L\t%s\n' "$st_root"
    return 0
  fi
  [ -d "$st_root" ] || return 0
  # Two copies of the expression go into one find: the caller's ("$1".."$n")
  # selects plain files, and its link twin -- appended after it, each
  # `-type f` swapped for `-type l` and one `-exec test -f {} ;` added last --
  # selects file links.
  # POSIX sh has no arrays, so each copy is a string of quoted positional
  # references ("$1" "$2" ...) that eval expands, never the words themselves.
  st_n=$# st_i=0 st_f='' st_l='' st_ty='' st_tf=''
  for st_a in "$@"; do
    st_i=$((st_i + 1)); st_f="$st_f \"\${$st_i}\""
    if [ -n "$st_ty" ]; then
      st_ty=''
      if [ "$st_a" = f ]; then set -- "$@" -type l; st_tf=1
      else set -- "$@" -type "$st_a"; fi
    elif [ "$st_a" = -type ]; then st_ty=1; continue
    else set -- "$@" "$st_a"; fi
  done
  [ -z "$st_ty" ] || set -- "$@" -type
  [ -z "$st_tf" ] || set -- "$@" -exec test -f '{}' ';'
  st_i=$st_n
  while [ "$st_i" -lt $# ]; do st_i=$((st_i + 1)); st_l="$st_l \"\${$st_i}\""; done
  # shellcheck disable=SC2086 # $st_h is empty or -H; unquoted so empty drops out
  eval "find \$st_h \"\$st_root\" -mindepth 1 \\( $st_f -exec printf 'F\\t%s\\n' {} + \\) \\
    -o \\( $st_l -exec printf 'L\\t%s\\n' {} + \\) \\
    -o \\( -type l -exec test -d {} \\; -exec printf 'L\\t%s\\n' {} + \\)" || true
}
# No 2>/dev/null above: a find that cannot run (unsupported primary, unreadable
# dir) must say so on stderr rather than leave an empty, silently-PASSing scan.

# scanned <scan_tree-output> -- the selected files, one per line.
scanned() {
  printf '%s\n' "$1" | awk -F'\t' '$1 == "F" { print $2 }'
}

# real <dir> -- its physical path, empty when it does not resolve.
real() { (cd -P -- "$1" 2>/dev/null && pwd -P); }

# real_target <link> -- the physical path a skipped link points at: real for a
# dir, and for a file link its final target's real dir plus its name (the
# chain is walked by readlink, at most 40 hops -- a loop resolves to nothing).
# Only the path is resolved; the target is never opened (issue #98).
real_target() {
  [ -d "$1" ] && { real "$1"; return; }
  rt_p=$1 rt_i=0
  while [ -L "$rt_p" ]; do
    rt_i=$((rt_i + 1)); [ "$rt_i" -le 40 ] || return 0
    rt_t=$(readlink -- "$rt_p") || return 0
    case $rt_t in /*) rt_p=$rt_t ;; *) rt_p=$(dirname -- "$rt_p")/$rt_t ;; esac
  done
  rt_d=$(real "$(dirname -- "$rt_p")") && [ -n "$rt_d" ] &&
    printf '%s/%s\n' "$rt_d" "$(basename -- "$rt_p")"
}

# bundle_scan <root> [find-expr]... -- scan_tree over a skill's shipped
# bundle, shared by Check 15 and Checks 17/18 (issue #87) so both agree on
# what it is: test trees, caches and vendored deps are pruned, self-test and
# fixture files excluded. Extra primaries (Check 15's script-type filter)
# narrow the selected files. The pruned names are bundle_prune_names, the one
# list both the find expression and bundle_prune_re are built from.
bundle_prune_names='tests __pycache__ .git node_modules .venv venv site-packages'
bundle_scan() {
  bs_root=$1; shift
  bs_prune=''
  for bs_n in $bundle_prune_names; do bs_prune="$bs_prune -o -name $bs_n"; done
  # shellcheck disable=SC2086 # split on purpose: one find word per token, no glob chars
  scan_tree -H "$bs_root" \( ${bs_prune# -o } \) -prune \
    -o -type f "$@" ! -iname '*selftest*' ! -iname '*selfcheck*' ! -iname 'test_*' ! -iname '*_test.*'
}
# The same names as an awk ERE (bracketed dots, not backslashes: awk -v would
# eat the escape).
# shellcheck disable=SC2086 # split on purpose, as in bundle_scan
bundle_prune_re=$(printf '%s\n' $bundle_prune_names | sed 's/[.]/[.]/g' | paste -sd '|' -)

# skipped [-p] <scan_tree-output> <prefix> [root]... -- the skipped links as one
# comma-separated list, <prefix> stripped, sorted (find walks in readdir
# order, which differs across filesystems); empty when none. A link already
# covered is dropped: a dir link whose target lies inside one of the scan's own
# non-symlink <root>s (`lib/current -> v2`), and a file link whose target is
# itself one of the scan's `F` files (`lib/alias.sh -> run.sh`) -- that content
# was read under its real path. A file target the filter did not select
# (`lib/net.py -> ../data/net.txt`, a self-test name, a pruned dir) was never
# read, so its link is still reported.
# -p: the scan was a bundle_scan, so a dir target under a pruned dir (`tests/`)
# was never read and its link is still reported.
skipped() {
  sk_re=''
  [ "$1" = -p ] && { sk_re="/($bundle_prune_re)/"; shift; }
  sk_out=$1 sk_pre=$2; shift 2
  sk_roots=''
  for sk_r in "$@"; do
    [ -L "$sk_r" ] && continue # a symlinked root was itself skipped, covers nothing
    sk_r=$(real "$sk_r") && [ -n "$sk_r" ] && sk_roots="$sk_roots$sk_r
"
  done
  sk_files='' sk_fdone=''
  printf '%s\n' "$sk_out" | awk -F'\t' '$1 == "L" { print $2 }' | while IFS= read -r sk_l; do
    sk_t=$(real_target "$sk_l") || sk_t=''
    if [ -d "$sk_l" ]; then
      printf '%s' "$sk_roots" | awk -v t="$sk_t/" -v re="$sk_re" '
        index(t, $0 "/") == 1 && (re == "" || substr(t, length($0) + 1) !~ re) { f = 1 }
        END { exit !f }' && continue
    elif [ -n "$sk_t" ]; then
      # The scanned files' physical paths, resolved once, on the first file link.
      [ -n "$sk_fdone" ] || {
        # `|| :` -- under set -e a failed lookup must not end this loop early.
        sk_files=$(scanned "$sk_out" | while IFS= read -r sk_f; do
          [ -z "$sk_f" ] || real_target "$sk_f" || :; done)
        sk_fdone=1
      }
      printf '%s\n' "$sk_files" | grep -qxF -- "$sk_t" && continue
    fi
    printf '%s\n' "${sk_l#"$sk_pre"}"
  done | LC_ALL=C sort | awk '{ s = s (s == "" ? "" : ", ") $0 } END { print s }'
}

# flag_skipped <result> <note> <links> -- sets fr/fn: a PASS or N/A becomes
# WARN and the note names the links, so a skipped dir or file is never silent.
flag_skipped() {
  fr=$1 fn=$2
  [ -n "$3" ] || return 0
  case $fr in PASS|N/A) fr=WARN ;; esac
  fn="$fn; symlink(s) not followed, unscanned: $3"
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
# find, not a bare */*.md glob -- also catches emoji in nested reference
# subdirectories (codex PR #16 FOLLOW-UP).
ref_scan=$(scan_tree "$refdir" -type f -name '*.md')
scan_files="$file
$(scanned "$ref_scan")"
ref_links=$(skipped "$ref_scan" "$dir/" "$refdir")
# Portable (non-PCRE) stand-in for grep -P '[\x{1F000}-\x{1FAFF}\x{FE0F}]':
# BSD/POSIX grep ships no -P at all, and GNU grep needs a PCRE build that
# isn't guaranteed either (agy PR #16 BLOCKER). UTF-8 encodes the whole
# U+1F000-U+1FFFF block -- a superset of this rubric's U+1F000-U+1FAFF, so
# this over-matches by a few hundred rarely-used codepoints on purpose -- as
# a 4-byte sequence with lead bytes F0 9F, and U+FE0F (variation selector) as
# the fixed 3-byte sequence EF B8 8F. Byte matching, not character matching,
# so LC_ALL=C keeps grep from trying (and failing) to validate multibyte
# sequences under the caller's locale.
emoji_lead=$(printf '\360\237')
emoji_vs16=$(printf '\357\270\217')
emoji_hits=0
# Newline-split, not word-split, so a reference file with a space in its path is still scanned.
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # -o (occurrences), not -c (matching lines) -- a line with two glyphs must
  # count as two, not one (agy PR #16 BLOCKER, round 2).
  c=$( { LC_ALL=C grep -oF -e "$emoji_lead" -e "$emoji_vs16" "$f" 2>/dev/null || true; } | wc -l | tr -d ' ')
  emoji_hits=$((emoji_hits + c))
done <<EOF
$scan_files
EOF
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
  allowlist="$tool_dir/../references/allowed-emoji-skills.txt"
  if [ ! -f "$allowlist" ]; then
    r11=WARN; n11='allowlist file missing'
  elif grep -qE "^${key}([[:space:]]|#|\$)" "$allowlist" 2>/dev/null; then
    r11='N/A'; n11="allowlisted under $key"
  else
    r11=FAIL; n11="$emoji_hits emoji glyph(s), key '$key' not in allowed-emoji-skills.txt"
  fi
fi
# An allowlisted skill stays N/A: emoji behind the link could not FAIL it anyway.
flag_skipped "$r11" "$n11" "$ref_links"; [ "$r11" = N/A ] || r11=$fr; n11=$fn

# ---------- Check 13: Model Recommendation Metadata (shape validation) ----------
# Scoped to the metadata: block specifically -- searching the whole
# frontmatter for a bare tier:/reason:/etc. let an unrelated top-level key
# produce a false PASS (codex PR #16 BLOCKER).
meta_block=$(printf '%s\n' "$fm" | awk '
  /^metadata:/ { inblock = 1; next }
  inblock && /^[A-Za-z_-]+:/ { exit }
  inblock { print }
')
if printf '%s\n' "$fm" | grep -qE '^disable-model-invocation:[[:space:]]*true'; then
  r13='N/A'; n13='disable-model-invocation: true'
elif ! printf '%s\n' "$meta_block" | grep -q 'model_recommendation:'; then
  if [ "$GATE_FAIL" -eq 1 ]; then
    r13=FAIL; n13='metadata.model_recommendation absent (migration gate closed)'
  else
    r13=WARN; n13='metadata.model_recommendation absent (migration gate open)'
  fi
else
  tier=$(printf '%s\n' "$meta_block" | awk -F': *' '/^[[:space:]]*tier:/ { print $2; exit }' | tr -d ' "')
  reason=$(printf '%s\n' "$meta_block" | awk -F': *' '/^[[:space:]]*reason:/ { print $2; exit }')
  claude=$(printf '%s\n' "$meta_block" | awk -F': *' '/^[[:space:]]*claude:/ { print $2; exit }' | tr -d ' "')
  nonclaude=$(printf '%s\n' "$meta_block" | awk -F': *' '/^[[:space:]]*non_claude:/ { print $2; exit }' | tr -d ' "')
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
# ponytail: this word list is checks.md's own "Network signals" list
# (references/checks.md, Check 15), verbatim -- it will flag a comment that
# merely mentions a URL as readily as a real network call (codex PR #16
# round-2 BLOCKER, declined: the same ambiguity exists for a human reading
# the file by eye, which is what this check replaced; worst case is a WARN,
# not a FAIL, and the note always names the file for a human to re-check).
net_pattern='requests|httpx|urllib|http\.client|socket|aiohttp|curl|wget|fetch\(|https?://'
# Every *.sh / *.py anywhere under the skill dir (issue #61): network code in
# a package dir (<pkg>/constants.py) is still shipped and still scanned by
# external scanners. Test trees, caches and vendored deps are pruned, and
# self-test/fixture files are excluded -- they exercise capability words in
# synthetic examples, not the skill's own runtime surface.
# -mindepth 1: a skill dir itself named e.g. `tests` must not prune its own root.
# -H: $dir is a logical path, often a symlinked skill dir; plain find would not enter it.
# Only that root is dereferenced; links inside the skill stay unfollowed (issue #32)
# and are named in the note instead (issue #77).
# selftest.sh runs Check 15 on this very skill: keep URLs and signal words out of comments here.
helper_scan=$(bundle_scan "$dir" \( -name '*.sh' -o -name '*.py' \))
scripts=$(scanned "$helper_scan")
net_hit=0
hosts=''
# Newline-split, not word-split, so a helper path with a space is still scanned.
while IFS= read -r s; do
  [ -f "$s" ] || continue
  # Exclude lines that assign a *_pattern = variable, spaced or not (this
  # file's own net_pattern definition line included) -- a helper quoting the
  # signal words as documentation, not calling them, must not self-trip
  # (agy PR #16 BLOCKER: the old exact-string '_pattern=' missed spaced
  # variants like '_pattern =').
  body=$(grep -vE '_pattern[[:space:]]*=' "$s" 2>/dev/null || true)
  printf '%s\n' "$body" | grep -qE "$net_pattern" && net_hit=1
  # Skip any user[:token]@ so the host, not the user name, is what gets checked.
  # Two passes, both kept: RFC 3986 allows , ; ( ) in userinfo, so a URL such
  # as scheme://u,p@evil.io really goes to evil.io (pass 1 must not miss it),
  # yet in code those same characters usually end the URL, and a later
  # 'u@b.io' argument must not hide the URL's own host (pass 2, #68). Pass 2
  # allows only unreserved characters, % (of pct-encoding) and : (#79), so any
  # other character ends it; whatever it skips is userinfo under any reading.
  # Quotes end the userinfo in both. Reporting both trades an occasional false
  # WARN for never missing a destination. (No literal URL here: this file is
  # itself a Check 15 helper, and one would make skill-check flag itself.)
  for ui in "[^/?#@[:space:]\"']" '[A-Za-z0-9._~%:-]'; do
    hosts="$hosts
$(printf '%s\n' "$body" | grep -oiE "https?://($ui*@)?[A-Za-z0-9._-]+" | sed -E 's|^[A-Za-z]+://||; s|^.*@||')"
  done
done <<EOF
$scripts
EOF
# Literal hosts the SKILL.md never names (scanner UNDECLARED_NETWORK_DESTINATION).
# Loopback, the RFC 2606 example.{com,org,net} domains and dotless
# placeholders (a URL whose host is just `host`, in a comment) are not destinations.
# SKILL.md names a host only as a whole host-shaped token, so neither
# `notacme.io` nor `sub.acme.io` counts as naming `acme.io`. A host may carry
# an underscore inside (my_svc.acme.io), but markdown `_emphasis_` wraps a
# token in underscores that are not part of it, so wrapping ones are
# stripped like a sentence-final dot.
named=$(grep -oE '[A-Za-z0-9_][A-Za-z0-9._-]*' "$file" | sed -E 's/^_+//; s/[._]+$//' | tr '[:upper:]' '[:lower:]')
undeclared=''
# Trailing underscores are emphasis and trailing dots are a sentence end or an
# ellipsis (`host...`), not host -- stripped as on the named side above.
for h in $(printf '%s\n' "$hosts" | tr '[:upper:]' '[:lower:]' | sed -E 's/[._]+$//' | sort -u); do
  case $h in
    *.*) ;;
    *) continue ;;
  esac
  case $h in
    0.0.0.0|example.com|example.org|example.net|*.example.com|*.example.org|*.example.net) continue ;;
    127.*[!0-9.]*) ;; # 127.evil.com is a real host, not loopback
    127.*) continue ;;
  esac
  printf '%s\n' "$named" | grep -qxF -e "$h" && continue
  # Name the first helper (sorted, so stable across filesystems) carrying the
  # host as a URL host -- after the scheme's // or a userinfo @, and ending
  # at a non-host character -- so sub.<host>, a /<host>/ path segment or a
  # bare mention elsewhere does not get the blame.
  hre=$(printf '%s' "$h" | sed 's/\./\\./g')
  # One grep over every helper: $scripts is split on newline only (IFS is a
  # newline, globbing off) so a spaced path stays one argument.
  # shellcheck disable=SC2086 # split on newline on purpose, see above
  src=$(IFS='
'; set -f; set -- $scripts; [ "$#" -gt 0 ] || exit 0
    grep -liE -e "(//|@)${hre}[._]*([^a-z0-9._-]|\$)" "$@" 2>/dev/null | sort | head -n 1)
  undeclared="$undeclared $h${src:+ (${src#"$dir"/})}"
done
undeclared=${undeclared# }
# The compatibility: block only -- checking "network:" against the whole
# frontmatter let an unrelated top-level field or prose mention falsely
# satisfy the declaration (codex PR #16 BLOCKER).
compat_block=$(printf '%s\n' "$fm" | awk '
  /^compatibility:/ { inblock = 1; next }
  inblock && /^[A-Za-z_-]+:/ { exit }
  inblock { print }
')
if [ -z "$(printf '%s' "$scripts" | tr -d '[:space:]')" ]; then
  r15='N/A'; n15='skill ships no executable helpers'
elif [ "$net_hit" -eq 0 ]; then
  r15=PASS; n15='no network signal in helpers'
elif printf '%s\n' "$compat_block" | grep -qE '^[[:space:]]*network:'; then
  r15=PASS; n15='network signal present, compatibility.network declared'
else
  r15=WARN; n15='network signal present, compatibility.network not declared'
fi
if [ -n "$undeclared" ]; then
  if [ "$r15" = WARN ]; then n15="$n15; "; else n15=''; fi
  r15=WARN; n15="${n15}helper host(s) not named in SKILL.md: $undeclared"
fi
flag_skipped "$r15" "$n15" "$(skipped -p "$helper_scan" "$dir/" "$dir")"; r15=$fr n15=$fn

# ---------- Check 16: Description Length ----------
# Fold a `description:` value -- inline or a `>`/`>-`/`>+`/`|`/`|-`/`|+`
# block -- to one whitespace-normalised line, stopping at the next top-level
# key (agy PR #16 FOLLOW-UP, round 2: `>-?`/`\|-?` missed the plain and `+`
# forms). ponytail: explicit numeric indentation indicators (`>2-`) are not
# matched -- no SKILL.md in this repo uses one; add if that changes.
desc=$(printf '%s\n' "$fm" | awk '
  /^description:[[:space:]]*>[+-]?[[:space:]]*$/ { inblock = 1; next }
  /^description:[[:space:]]*\|[+-]?[[:space:]]*$/ { inblock = 1; next }
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
  \'*\') desc=${desc#\'}; desc=${desc%\'} ;;
esac
if [ -z "$desc" ]; then
  r16='N/A'; n16='no description found in frontmatter'
else
  # Probe for a UTF-8 locale actually installed on this system instead of
  # assuming C.utf8 -- an uninstalled locale makes wc -m silently degrade to
  # byte counting, over-reporting a Korean description's length by ~3x and
  # false-FAILing this check (codex PR #16 round-3 BLOCKER).
  utf8_locale=''
  for cand in C.utf8 C.UTF-8 en_US.UTF-8 en_US.utf8; do
    locale -a 2>/dev/null | grep -qiFx "$cand" && { utf8_locale=$cand; break; }
  done
  degraded_note=''
  if [ -z "$utf8_locale" ]; then
    utf8_locale=C.utf8
    degraded_note=' (no UTF-8 locale found on this system -- count may be approximate)'
  fi
  len=$(printf '%s' "$desc" | LC_ALL="$utf8_locale" wc -m | tr -d ' ')
  if [ "$len" -le 250 ]; then
    r16=PASS; n16="$len characters$degraded_note"
  elif [ "$len" -le 400 ]; then
    # Justifying comment per checks.md's "Justifying comment" rubric; scoped
    # to `#` comment lines so a `description:` value can't match by accident.
    if printf '%s\n' "$fm" | grep -qiE '^[[:space:]]*#.*check[ -]?16([^0-9]|$)'; then
      r16=PASS; n16="$len characters (251-400 band, justified by comment)$degraded_note"
    else
      r16=WARN; n16="$len characters (251-400 band, needs a justifying comment)$degraded_note"
    fi
  else
    r16=FAIL; n16="$len characters (over 400)$degraded_note"
  fi
fi

# ---------- shared scan set for Checks 17, 18 ----------
# SKILL.md plus every text file anywhere under the skill dir -- the bundle a
# single-skill install (Hermes tap, `npx skills add`) copies. Discovery is
# recursive with Check 15's prune list (issue #87), so the two checks agree on
# what the bundle is: a helper at <pkg>/run.sh is seen by both.
# Self-test/fixture files are excluded as in Check 15: they spell out `../`
# and CLAUDE_PLUGIN_ROOT as synthetic examples, not as the skill's own
# runtime surface. Paths are printed relative to the skill dir.
port_scan_out=$(
  cd "$dir" && bundle_scan . ! -path ./SKILL.md |
    awk -F'\t' -v OFS='\t' '{ sub(/^\.\//, "", $2); print }'
)
# Text files only: grep -Il over the list rather than a grep per file. The list
# goes NUL-separated through xargs, so a spaced path stays one argument and a
# large skill cannot overflow ARG_MAX; it is never empty (SKILL.md heads it).
# A file grep cannot read says so on stderr, as scan_tree's find does.
port_files=$(
  cd "$dir" && printf 'SKILL.md\n%s\n' "$(scanned "$port_scan_out")" | awk 'NF' |
    tr '\n' '\0' | xargs -0 grep -Il -e . -- | sort
)
# SKILL.md heads the read set but not the scan, so it is added as an `F` file:
# a file link to it was read and is not reported.
port_links=$(cd "$dir" && skipped -p "$(printf 'F\tSKILL.md\n%s' "$port_scan_out")" "" .)

# port_scan <mode> -- one awk pass over $port_files, run from $dir.
#   mode=escape: print `file:line -> path` for every `../` token (after a
#     `(`, backtick, quote, `=` or whitespace) that names a file (ends in
#     `name.ext`; `#anchor` dropped) and that, normalised as a string
#     against the referencing file's own directory, climbs above the skill
#     dir. Symlinks are never followed (issue #32 decision: deterministic);
#     a symlinked dir or file the scan set skipped is reported, not hidden
#     (#77, #98).
#     Also (issue #34): a skill-dir variable + `/../` path, resolved from the
#     skill root and checked even inside fences; and, in references/, a `../`
#     path whose file-relative target is missing but whose skill-root-relative
#     target escapes.
#   mode=root:   print `file:line` for every unprotected dollar-expansion of
#     CLAUDE_PLUGIN_ROOT (braced or bare) that would execute -- inside a
#     fence, on a non-comment script line, or in markdown prose only as a
#     command (`bash "<expansion>/..."`) -- then `USES` if any exists.
#     (Worded without a literal expansion so this script does not audit
#     itself.)
# Markdown fences (``` / ~~~) are skipped by escape mode (illustrative
# examples) and are the "code block" unit for root mode's guard rule; a
# non-.md file is one block. The other-harness hint counts anywhere in the
# same file -- sibling skills put it in the prose paragraph or section
# around the fence, rarely in the same blank-line paragraph.
port_scan() {
  ps_mode=$1
  # $port_files is split on newline only (IFS is a newline, globbing off) so a
  # spaced path reaches awk as one file name.
  # shellcheck disable=SC2086 # split on newline on purpose, see above
  (cd "$dir" && IFS='
' && set -f && set -- $port_files && awk -v mode="$ps_mode" '
    # Only a path naming a file (`name.ext`; callers drop `#anchor`) is a
    # bundle dependency; a bare `../..` or `../../.git` in prose is shell talk.
    function isfile(t) { return t ~ /[^.\/]\.[A-Za-z0-9]+$/ }
    # escapes <path> <depth> -- 1 if string-normalising <path> from a dir
    # <depth> levels below the skill root ever climbs above the root.
    function escapes(t, depth,   k, j, part) {
      k = split(t, part, "/")
      for (j = 1; j <= k; j++) {
        if (part[j] == "..") depth--
        else if (part[j] != "." && part[j] != "") depth++
        if (depth < 0) return 1
      }
      return 0
    }
    function flush(   i) {
      for (i = 1; i <= nl; i++) {
        if (U[i]) {
          uses = 1
          if (L[i] ~ /\$\{CLAUDE_PLUGIN_ROOT:-/) continue
          if (G[B[i]] || hint) continue
          print FN[i] ":" LN[i]
        }
      }
      nl = 0; hint = 0; split("", G); split("", U)
    }
    FNR == 1 {
      if (mode == "root") flush()
      md = (FILENAME ~ /\.md$/); fence = 0; blk++
      n = split(FILENAME, seg, "/"); base = n - 1
      dirname = FILENAME; sub(/\/[^\/]*$/, "", dirname)
    }
    {
      line = $0
      if (md && line ~ /^[[:space:]]*(```|~~~)/) { fence = !fence; blk++; next }
      if (mode == "root") {
        nl++; L[nl] = line; B[nl] = blk; FN[nl] = FILENAME; LN[nl] = FNR
        # A "use" is an expansion that would execute: any in a fence or a
        # non-comment script line; in markdown prose only a command
        # invocation (`bash "$..."`), not a sentence naming the variable.
        U[nl] = 0
        if (line ~ /\$\{?CLAUDE_PLUGIN_ROOT/) {
          if (md && !fence) U[nl] = (line ~ /(bash|sh|source|\.|python3?|node|exec)[ \t]+"?\$\{?CLAUDE_PLUGIN_ROOT/)
          else U[nl] = (md || line !~ /^[ \t]*#/)
        }
        if (line ~ /\[\[? -[nz] "?\$\{?CLAUDE_PLUGIN_ROOT/) G[blk] = 1
        if (tolower(line) ~ /other harness|다른 하네스|그 외 하네스|elsewhere export|export claude_plugin_root=|hermes_skill_dir/) hint = 1
        next
      }
      # A skill-dir variable is an executed path, checked even in a fence;
      # its `../` is resolved against the skill root (issue #34 pattern 1).
      rest = line
      while (match(rest, /\$\{?(HERMES_|CLAUDE_)?SKILL_DIR(:-[^}]*)?\}?\/\.\.\/[^ \t)`"'"'"'<>,;|]*/)) {
        tok = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        sub(/^[^\/]*\//, "", tok); sub(/#.*/, "", tok)
        if (isfile(tok) && escapes(tok, 0)) print FILENAME ":" FNR " -> " tok
      }
      if (md && fence) next
      rest = line
      while (match(rest, /(^|[ \t(`"'"'"'=])\.\.\/[^ \t)`"'"'"'<>,;|]*/)) {
        tok = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
        sub(/^[^.]/, "", tok); sub(/#.*/, "", tok)
        if (!isfile(tok)) continue
        if (escapes(tok, base)) print FILENAME ":" FNR " -> " tok
        # references/ files often write paths relative to the skill root
        # (issue #34 pattern 2): flag when the file-relative target is
        # missing AND the root-relative one leaves the skill. getline < 0
        # means unopenable -- an existence test without forking a shell.
        else if (FILENAME ~ /^references\// && escapes(tok, 0)) {
          p = dirname "/" tok
          if ((getline _x < p) < 0) print FILENAME ":" FNR " -> " tok
          close(p)
        }
      }
    }
    END { if (mode == "root") { flush(); if (uses) print "USES" } }
  ' "$@")
}

# summarize <hits> -- first five hits joined by "; ", plus "(+N more)".
summarize() {
  printf '%s\n' "$1" | awk 'NF { n++; if (n <= 5) s = s (n > 1 ? "; " : "") $0 }
    END { if (n > 5) s = s " (+" n - 5 " more)"; print s }'
}

# ---------- Check 17: Bundle Self-containment ----------
esc=$(port_scan escape)
if [ -z "$esc" ]; then
  r17=PASS; n17='no relative path escapes the skill dir'
else
  r17=WARN; n17="$(printf '%s\n' "$esc" | grep -c .) path(s) outside the skill dir: $(summarize "$esc")"
fi

# ---------- Check 18: Plugin-root Fallback ----------
roots=$(port_scan root)
case $roots in
  '') r18='N/A'; n18='no CLAUDE_PLUGIN_ROOT expansion' ;;
  USES) r18=PASS; n18='every CLAUDE_PLUGIN_ROOT use has a fallback' ;;
  *)
    unprot=$(printf '%s\n' "$roots" | grep -v '^USES$')
    r18=WARN; n18="$(printf '%s\n' "$unprot" | grep -c .) CLAUDE_PLUGIN_ROOT use(s) with no fallback: $(summarize "$unprot")"
    ;;
esac
flag_skipped "$r17" "$n17" "$port_links"; r17=$fr n17=$fn
flag_skipped "$r18" "$n18" "$port_links"; r18=$fr n18=$fn

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
out 17 "$r17" "$n17"
out 18 "$r18" "$n18"
out 19 "$j19" 'auditor judgment'

[ -n "$j2" ] || exit 0

total=$((19 - na))
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
