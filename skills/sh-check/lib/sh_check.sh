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

# IS_SOURCED heuristic, SKILL.md Step 1: location, an interactive guard near
# the top, or the absence of a shebang.
sourced=0
case $file in
  */shell-common/functions/*|*/bash/*|*/zsh/*) sourced=1 ;;
esac
if head -20 "$file" | grep -qF 'case $- in *i*'; then sourced=1; fi
case $shebang in '#!'*) ;; *) sourced=1 ;; esac

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
guard='case \$- in \*i\*'
if [ "$sourced" -eq 0 ]; then
  r2='N/A'; n2='executable script, no guard needed'
elif head -10 "$file" | grep -qF 'case $- in *i*'; then
  r2=PASS; n2='guard within the first 10 lines'
elif has "$guard"; then
  r2=WARN; n2='guard present but below the first 10 lines'
else
  r2=FAIL; n2='sourced file with no interactive guard'
fi

# ---------- Check 4: Naming Convention ----------
funcs=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*\(\) *\{' "$file" 2>/dev/null |
  sed 's/().*//' || true)
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
locals=$(count '(^|[^A-Za-z_])local ')
guards=$(count 'emulate -L sh')
if [ "$shell_specific" -eq 1 ]; then
  r5='N/A'; n5='single-shell tree (bash/ or zsh/)'
elif [ "$nfunc" -eq 0 ] || [ "$locals" -eq 0 ]; then
  r5='N/A'; n5='no cross-shell function using local'
elif [ "$guards" -ge "$nfunc" ]; then
  r5=PASS; n5="emulate -L sh guard present ($guards hit(s), $nfunc function(s))"
elif [ "$guards" -gt 0 ]; then
  r5=WARN; n5="emulate -L sh in only $guards of $nfunc function(s)"
elif [ "$in_common" -eq 1 ]; then
  r5=FAIL; n5='shell-common file, no emulate -L sh anywhere'
else
  r5=WARN; n5='no emulate -L sh guard'
fi

# ---------- Check 6: Help Flag ----------
if ! has '--help|-h\)|-h\|'; then
  r6=FAIL; n6='no -h/--help handling'
elif printf '%s\n' "$funcs" | grep -qE 'help'; then
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
elif [ $((pass * 100 / total)) -ge 80 ] && [ "$fail" -eq 0 ]; then
  verdict=GOOD
elif [ $((pass * 100 / total)) -ge 60 ] || [ "$fail" -eq 1 ]; then
  verdict='NEEDS WORK'
else
  verdict=POOR
fi
printf 'score\t%s/%s\t%s\n' "$pass" "$total" "$verdict"
