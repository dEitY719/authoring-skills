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
# ponytail: $scan_files/$scripts/$port_files are built via unquoted word-splitting, so a
# path containing a space would break them. Every skill/file name in this
# repo's marketplace convention is kebab-case with no spaces (naming-
# convention.md), so this is accepted rather than reworked into a POSIX-sh
# array substitute. Upgrade path if that convention ever breaks: switch to
# NUL-delimited `find -print0` and a `while IFS= read -r -d ''` loop.

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
  # find, not a bare */*.md glob -- also catches emoji in nested reference
  # subdirectories (codex PR #16 FOLLOW-UP).
  scan_files="$scan_files $(find "$refdir" -type f -name '*.md' 2>/dev/null)"
fi
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
for f in $scan_files; do
  # -o (occurrences), not -c (matching lines) -- a line with two glyphs must
  # count as two, not one (agy PR #16 BLOCKER, round 2).
  c=$( { LC_ALL=C grep -oF -e "$emoji_lead" -e "$emoji_vs16" "$f" 2>/dev/null || true; } | wc -l | tr -d ' ')
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
  allowlist="$tool_dir/../references/allowed-emoji-skills.txt"
  if [ ! -f "$allowlist" ]; then
    r11=WARN; n11='allowlist file missing'
  elif grep -qE "^${key}([[:space:]]|#|\$)" "$allowlist" 2>/dev/null; then
    r11='N/A'; n11="allowlisted under $key"
  else
    r11=FAIL; n11="$emoji_hits emoji glyph(s), key '$key' not in allowed-emoji-skills.txt"
  fi
fi

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
  # Exclude lines that assign a *_pattern = variable, spaced or not (this
  # file's own net_pattern definition line included) -- a helper quoting the
  # signal words as documentation, not calling them, must not self-trip
  # (agy PR #16 BLOCKER: the old exact-string '_pattern=' missed spaced
  # variants like '_pattern =').
  grep -vE '_pattern[[:space:]]*=' "$s" 2>/dev/null | grep -qE "$net_pattern" && net_hit=1
done
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
# SKILL.md plus every text file under references/, lib/, scripts/ -- the
# bundle a single-skill install (Hermes tap, `npx skills add`) copies.
# Self-test/fixture files are excluded as in Check 15: they spell out `../`
# and CLAUDE_PLUGIN_ROOT as synthetic examples, not as the skill's own
# runtime surface. Paths are printed relative to the skill dir.
port_files=$(
  cd "$dir" && {
    echo SKILL.md
    for d in references lib scripts; do
      [ -d "$d" ] && find "$d" -type f ! -iname '*selftest*' ! -iname '*selfcheck*' ! -iname 'test_*' ! -iname '*_test.*'
    done
  } | while IFS= read -r f; do grep -Iq . "$f" 2>/dev/null && printf '%s\n' "$f"; done | sort
)

# port_scan <mode> -- one awk pass over $port_files, run from $dir.
#   mode=escape: print `file:line -> path` for every `../` token (after a
#     `(`, backtick, quote, `=` or whitespace) that names a file (ends in
#     `name.ext`; `#anchor` dropped) and that, normalised as a string
#     against the referencing file's own directory, climbs above the skill
#     dir. Symlinks are never followed (issue #32 decision: deterministic).
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
  # shellcheck disable=SC2086 # $port_files is word-split on purpose (see header ponytail)
  (cd "$dir" && awk -v mode="$1" '
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
  ' $port_files)
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

[ -n "$j2" ] || exit 0

total=$((18 - na))
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
