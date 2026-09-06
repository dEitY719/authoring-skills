#!/bin/sh
# sh_check.sh -- the mechanical half of authoring:sh-check.
#
# Usage: sh_check.sh <script-path> [c3 c8 c9 c10]
#   c3/c8/c9/c10 are the auditor's own calls for the four checks no grep can
#   decide -- 3 Section Anatomy, 8 Input Validation, 9 Verdict Output,
#   10 Next-action Hint -- each PASS | WARN | FAIL | N/A. Pass all four or none.
#
# stdout: check<TAB>result<TAB>note, one row per decided check, ascending id.
#         With the four judgments it also emits every row plus a final
#         score<TAB><pass>/<effective-total><TAB><VERDICT>
#         computed per references/report-template.md "Verdict Computation".
# exit:   0 report written | 2 bad usage or unreadable file
#
# Read-only: never edits the audited file. Criteria: references/checks.md.

set -eu

file=${1:-}

case $file in
  -h|--help|help)
    echo "usage: sh_check.sh <script-path> [c3 c8 c9 c10]"
    exit 0
    ;;
  '')
    echo "sh_check: missing <script-path>" >&2
    exit 2
    ;;
esac

[ -r "$file" ] || { echo "sh_check: cannot read '$file'" >&2; exit 2; }

j3='' j8='' j9='' j10=''
if [ "$#" -eq 5 ]; then
  j3=$2 j8=$3 j9=$4 j10=$5
elif [ "$#" -ne 1 ]; then
  echo "sh_check: pass the four judgment results (c3 c8 c9 c10) or none" >&2
  exit 2
fi
for j in "$j3" "$j8" "$j9" "$j10"; do
  case $j in
    ''|PASS|WARN|FAIL|N/A) ;;
    *) echo "sh_check: judgment must be PASS|WARN|FAIL|N/A, got '$j'" >&2; exit 2 ;;
  esac
done

count() { grep -cE -e "$1" "$file" 2>/dev/null || true; }
has()   { grep -qE -e "$1" "$file" 2>/dev/null; }

shebang=$(head -1 "$file")

case $file in
  */shell-common/*) in_common=1 ;;
  *)                in_common=0 ;;
esac
case $file in
  */bash/*|*/zsh/*) shell_specific=1 ;;
  *)                shell_specific=0 ;;
esac

# IS_SOURCED heuristic, SKILL.md Step 1 and checks.md Check 2: location, an
# interactive guard near the top, a top-level `alias` in the opening lines, or
# the first line. A shebang alone never proves the file is executed rather than
# sourced -- checks.md Check 2 makes the N/A row conditional on `#!` *and*
# `chmod +x`, so an unexecutable fragment is sourced however it starts.
sourced=0
case $file in
  */shell-common/functions/*|*/bash/*|*/zsh/*) sourced=1 ;;
esac
head20=$(head -20 "$file")
if printf '%s\n' "$head20" | grep -qF 'case $- in *i*'; then sourced=1; fi
if printf '%s\n' "$head20" | grep -qE '^[[:space:]]*alias '; then sourced=1; fi
case $shebang in '#!'*) [ -x "$file" ] || sourced=1 ;; *) sourced=1 ;; esac

# ---------- Check 1: Shebang + POSIX Hygiene ----------
case $shebang in
  '#!'*)
    bashisms=$(count '\[\[|&>')
    if printf '%s' "$shebang" | grep -qE '^#! ?(/usr)?/bin/(env +)?sh$'; then
      if [ "$bashisms" -eq 0 ]; then
        r1=PASS; n1='#!/bin/sh, POSIX-only syntax'
      elif [ "$in_common" -eq 1 ]; then
        r1=FAIL; n1="shell-common file uses $bashisms bash-only construct(s)"
      else
        r1=WARN; n1="POSIX shebang but $bashisms bash-only construct(s)"
      fi
    elif [ "$in_common" -eq 1 ]; then
      r1=FAIL; n1='shell-common file must be #!/bin/sh'
    else
      r1=PASS; n1='bash-only shebang, allowed outside shell-common'
    fi
    ;;
  *)
    if [ "$in_common" -eq 1 ]; then
      r1=FAIL; n1='shell-common file with no shebang'
    else
      r1='N/A'; n1='sourced fragment with no shebang, outside shell-common'
    fi
    ;;
esac

# ---------- Check 2: Interactive Guard ----------
if [ "$sourced" -eq 0 ]; then
  r2='N/A'; n2='executable script, no guard needed'
elif head -10 "$file" | grep -qF 'case $- in *i*'; then
  r2=PASS; n2='guard within the first 10 lines'
elif grep -qF 'case $- in *i*' "$file" 2>/dev/null; then
  r2=WARN; n2='guard present but below the first 10 lines'
else
  r2=FAIL; n2='sourced file with no interactive guard'
fi

# One pass over the file yields, per function definition:
#   name<TAB>needs-guard<TAB>has-emulate-guard
# The opening brace may sit on the definition line, on the next line, or the
# whole body may be a one-liner, so the definition is recognised by `name()`
# alone and the remainder of that same line is scanned as body.
FUNCS=$(awk '
  function flush() {
    if (cur != "") printf "%s\t%d\t%d\n", cur, needs, guarded
    cur = ""
  }
  # checks.md Check 5 requires the guard for `local`, arrays *and* `set -x`,
  # so all three mark the function -- zsh traces and word-splits every one of
  # them differently, not just `local`.
  function body(line) {
    if (line ~ /(^|[^A-Za-z_])local[ \t]/) needs = 1
    if (line ~ /(^|[^A-Za-z_])set[ \t]+-[A-Za-z]*x([ \t]|$)/) needs = 1
    if (line ~ /(^|[^A-Za-z_])[A-Za-z_][A-Za-z0-9_]*\+?=\(/) needs = 1
    if (line ~ /\$\{?[A-Za-z_][A-Za-z0-9_]*\[/) needs = 1
    if (line ~ /emulate -L sh/) guarded = 1
  }
  # The body ends at the brace that closes it. Without this the lines after a
  # function -- a comment mentioning `emulate -L sh`, or top-level code -- were
  # still charged to it, so the next function inherited its state. Braces inside
  # strings are miscounted; an unbalanced one only degrades to the old
  # everything-leaks behaviour, never to a wrong early close.
  function track(line,   t, o, c) {
    t = line; o = gsub(/[{]/, "", t)
    t = line; c = gsub(/[}]/, "", t)
    if (o > 0) opened = 1
    depth += o - c
    if (opened && depth <= 0) flush()
  }
  /^[A-Za-z_][A-Za-z0-9_]*[ \t]*\(\)/ {
    flush()
    cur = $0
    sub(/[ \t]*\(\).*/, "", cur)
    needs = 0
    guarded = 0
    opened = 0
    depth = 0
    body($0)
    track($0)
    next
  }
  cur != "" { body($0); track($0) }
  END { flush() }
' "$file" 2>/dev/null || true)

# ---------- Check 4: Naming Convention ----------
funcs=$(printf '%s\n' "$FUNCS" | cut -f1 | grep -v '^$' || true)
if [ -z "$funcs" ]; then
  nfunc=0; camel=0; odd=0
else
  nfunc=$(printf '%s\n' "$funcs" | grep -c . || true)
  camel=$(printf '%s\n' "$funcs" | grep -cE '[a-z][A-Z]' || true)
  odd=$(printf '%s\n' "$funcs" | grep -cvE '^_?[a-z0-9_]+$' || true)
fi
if [ "$nfunc" -eq 0 ]; then
  r4='N/A'; n4='file defines no functions'
elif [ "$camel" -gt 0 ]; then
  r4=FAIL; n4="$camel camelCase name(s)"
elif [ "$odd" -eq 0 ]; then
  r4=PASS; n4="$nfunc function(s), all snake_case"
elif [ "$odd" -le 2 ]; then
  r4=WARN; n4="$odd name(s) off snake_case"
else
  r4=FAIL; n4="$odd of $nfunc name(s) off snake_case"
fi

# ---------- Check 5: ZSH Compat Guard ----------
# Counted per function, not file-wide: two guards inside one function must not
# cover a second, unguarded one.
need_guard=$(printf '%s\n' "$FUNCS" | awk -F'\t' '$2 == 1' | grep -c . || true)
have_guard=$(printf '%s\n' "$FUNCS" | awk -F'\t' '$2 == 1 && $3 == 1' | grep -c . || true)
if [ "$shell_specific" -eq 1 ]; then
  r5='N/A'; n5='single-shell tree (bash/ or zsh/)'
elif [ "$need_guard" -eq 0 ]; then
  r5='N/A'; n5='no cross-shell function needing the guard'
elif [ "$have_guard" -eq "$need_guard" ]; then
  r5=PASS; n5="emulate -L sh in all $need_guard function(s) that need it"
elif [ "$have_guard" -gt 0 ]; then
  r5=WARN; n5="emulate -L sh in $have_guard of $need_guard function(s) that need it"
elif [ "$in_common" -eq 1 ]; then
  r5=FAIL; n5='shell-common file, no emulate -L sh in any function'
else
  r5=WARN; n5='no emulate -L sh guard'
fi

# ---------- Check 6: Help Flag ----------
# The flag has to sit where an option is read -- a case pattern (`-h)`, `-h|`,
# `--help)`) or a test (`[ "$1" = "--help" ]`) -- on a line with no `#` before
# it. A bare `--help` anywhere also matched prose in comments and strings, and
# missed the spacing variants (`-h )`, `"--help" ]`).
help_arm='^[^#]*(^|[^-[:alnum:]_])(-h|--help)[^[:alnum:]]*[])|]'
# A `*help` function only counts as delegation when something calls it: a
# defined-but-unreferenced `render_help` used to satisfy this on its name alone.
# Which *public commands* route to it is not decidable here -- that stays with
# the auditor, and Check 6's N/A row is per function.
help_fn=0
for h in $(printf '%s\n' "$funcs" | grep -E 'help$' || true); do
  if grep -qE "(^|[^A-Za-z0-9_])$h([^A-Za-z0-9_(]|\$)" "$file" 2>/dev/null; then
    help_fn=1; break
  fi
done
if ! has "$help_arm"; then
  r6=FAIL; n6='no -h/--help handling'
elif [ "$help_fn" -eq 1 ]; then
  r6=PASS; n6='-h/--help delegates to a help function'
else
  r6=WARN; n6='help handled inline, not via a help function'
fi

# ---------- Check 7: UX Lib Usage ----------
ux=$(count 'ux_[a-z]')
raw=$(count '^[[:space:]]*(echo|printf|tput)[[:space:]]')
if [ "$ux" -gt 0 ] && [ "$raw" -eq 0 ]; then
  r7=PASS; n7="$ux ux_* call(s), no raw output"
elif [ "$ux" -gt 0 ]; then
  r7=WARN; n7="$raw raw echo/printf line(s) alongside $ux ux_* call(s)"
elif [ "$raw" -gt 0 ]; then
  r7=FAIL; n7="$raw raw echo/printf/tput line(s), no ux_lib"
else
  r7='N/A'; n7='no user-facing output'
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
out 2 "$r2" "$n2"
out 3 "$j3" 'auditor judgment'
out 4 "$r4" "$n4"
out 5 "$r5" "$n5"
out 6 "$r6" "$n6"
out 7 "$r7" "$n7"
out 8 "$j8" 'auditor judgment'
out 9 "$j9" 'auditor judgment'
out 10 "$j10" 'auditor judgment'

[ -n "$j3" ] || exit 0

total=$((10 - na))
if [ "$total" -le 0 ]; then
  verdict='N/A'
elif [ "$pass" -eq "$total" ]; then
  verdict=EXCELLENT
else
  pct=$((pass * 100 / total))
  if [ "$pct" -ge 80 ] && [ "$fail" -eq 0 ]; then
    verdict=GOOD
  elif [ "$pct" -ge 60 ] || [ "$fail" -eq 1 ]; then
    verdict='NEEDS WORK'
  else
    verdict=POOR
  fi
fi
printf 'score\t%s/%s\t%s\n' "$pass" "$total" "$verdict"
