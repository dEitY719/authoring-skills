#!/bin/sh
# sh_check.sh -- the mechanical half of authoring:sh-check.
#
# Usage: sh_check.sh <script-path> [c3 c8]
#   c3/c8 are the auditor's own calls for the two checks no grep can decide --
#   3 Section Anatomy, 8 Input Validation -- each PASS | WARN | FAIL | N/A.
#   Pass both or none.
#
# stdout: check<TAB>result<TAB>note, one row per decided check, ascending id;
#         then fn<TAB>function<TAB>vocab<TAB>next-ok/next-n<TAB>result, one row
#         per function returning a fixed-line verdict (none -> no fn rows);
#         then safety<TAB><id><TAB><result><TAB><note> for ids 11..14 and
#         safety-score<TAB><pass>/<effective-total>, both always, neither in
#         the score below.
#         With the two judgments it also emits every row plus a final
#         score<TAB><pass>/<effective-total><TAB><VERDICT>
#         computed per references/report-template.md "Verdict Computation".
# exit:   0 report written | 2 bad usage or unreadable file
#
# Read-only: never edits the audited file. Criteria: references/checks.md.

set -eu

file=${1:-}

case $file in
  -h|--help|help)
    echo "usage: sh_check.sh <script-path> [c3 c8]"
    exit 0
    ;;
  '')
    echo "sh_check: missing <script-path>" >&2
    exit 2
    ;;
esac

[ -r "$file" ] || { echo "sh_check: cannot read '$file'" >&2; exit 2; }

j3='' j8=''
if [ "$#" -eq 3 ]; then
  j3=$2 j8=$3
elif [ "$#" -ne 1 ]; then
  echo "sh_check: pass the two judgment results (c3 c8) or none" >&2
  exit 2
fi
for j in "$j3" "$j8"; do
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
# A top-level shell-common/tools/custom/*.sh is an executed bash entrypoint,
# never sourced: its expected shebang is #!/bin/bash, and #!/bin/sh is rejected
# by the dotfiles shebang hook (SSOT: dotfiles git/config/hook-config.sh
# DOTFILES_HOOKS_SHEBANG_SHELL_COMMON_CUSTOM). Subdirectories (lib/ etc.) are
# source-only and keep the shell-common #!/bin/sh rule.
custom_entry=0
case $file in
  */shell-common/tools/custom/*/*) ;;
  */shell-common/tools/custom/*.sh) custom_entry=1 ;;
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
    # A POSIX class (`[[:space:]]`) opens with `[[` too: drop every `[:name:]`
    # before counting, so only a real `[[ ]]` or `&>` is a bashism (issue #46).
    # An escaped `\[` (a literal bracket in a sed/grep regex such as
    # `s/^\[[^]]*\]//`) is dropped too: it never opens a `[[ ]]` test.
    bashisms=$(sed -E 's/\\\[//g; s/\[:[[:alpha:]]+:\]//g' "$file" | grep -cE -e '\[\[|&>' || true)
    if [ "$custom_entry" -eq 1 ]; then
      if [ "$shebang" = '#!/bin/bash' ]; then
        r1=PASS; n1='tools/custom entrypoint, #!/bin/bash as the hook expects'
      else
        r1=FAIL; n1='tools/custom entrypoint must be #!/bin/bash'
      fi
    elif printf '%s' "$shebang" | grep -qE '^#! ?(/usr)?/bin/(env +)?sh$'; then
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

# Two passes over the file. The first collects every non-empty var="..."
# assignment, so a "$var" NEXT can be resolved; the second yields, per function
# definition:
#   name<TAB>needs-guard<TAB>has-emulate-guard<TAB>vocab<TAB>next-n<TAB>next-ok<TAB>next-blank<TAB>net<TAB>table<TAB>args
# vocab is the number of distinct literal states (first printf argument) among
# the function's fixed-line printf '%s\n%s\n...' returns, `?` when a state is
# not a literal, `-` when the function has no such return. next-* judge the last
# argument of each return as Check 10 does: NEXT is command-shaped when it is a
# known command prefix or a hyphenated member of its family (`gh-flow prune 1`,
# issue #41), a /plugin:skill name, or `-` for a terminal state; a leading
# `cd <arg> && ` is stripped and the rest judged the same way (issue #47).
# The opening brace may sit on the definition line, on the next line, or the
# whole body may be a one-liner, so the definition is recognised by `name()`
# alone and the remainder of that same line is scanned as body.
# net counts calls to a transfer command (call_pattern) in command position that
# no enclosing if/elif or case arm gates on an opt-in token (issue #42):
# `"gh pr view 1"` as a NEXT string, `command -v gh` and comments are not calls.
# table is 1 when the body calls ux_table_row -- a help-table renderer such as
# `_gwt_help_rows_status`, which Check 9 must not mistake for a verdict (#104).
# args is 1 when the body reads its arguments ($1..$9, $@, $*, $#, or getopts /
# shift / `for x; do`; single-quoted text and ${#var} do not count) -- a function
# that never does takes no arguments, so Check 6 has no --help to ask of it (#106).
# The command names live only in the call_pattern assignment, which skill-check
# Check 15 skips as a *_pattern line -- keep them out of comments (issue #84).
# ponytail: prefix allow-list, anything else is WARN never FAIL (issue #36
# Decisions); widen next_cmds when a real command keeps landing in WARN.
# ponytail: opt-in is a name match on the condition (remote|network|online),
# not data flow -- widen opt_in when a real flag name keeps landing in WARN.
next_cmds='gwt|git|gh|ps'
opt_in='remote|network|online'
call_pattern='(^|[;&|(!{]|(then|do|else)[ \t])[ \t]*(gh|curl|wget)([ \t]|$)'
FUNCS=$(awk -v cmds="$next_cmds" -v opt="$opt_in" -v call="$call_pattern" '
  FNR == NR {
    t = $0
    while (match(t, /[A-Za-z_][A-Za-z0-9_]*="[^"]+"/)) {
      a = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH)
      k = a; sub(/=.*/, "", k); v = a; sub(/^[^=]*="/, "", v); sub(/"$/, "", v)
      val[k] = val[k] SUBSEP v
    }
    next
  }
  function flush(   voc) {
    voc = nfixed == 0 ? "-" : (dyn ? "?" : nvoc)
    if (cur != "") printf "%s\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%d\n", cur, needs, guarded, voc, n, ok, blank, net, tbl, args
    cur = ""
  }
  function judge(v) {
    n++
    if (v == "") { blank++; return }
    # `cd <arg> && rest` is judged by rest (issue #47).
    while (sub(/^cd [^ ;&|]+ && /, "", v)) ;
    if (v == "-" || v ~ ("^(" cmds ")(-[a-z0-9]+)* ") || v ~ /^\/[a-z0-9-]+:[a-z0-9-]+/) ok++
    # tail/ls/cat are English words too: only a flag, quote, $var or path
    # argument makes them a command (`tail -40 x`, not `tail the log`) -- #106.
    else if (v ~ /^(tail|ls|cat) [-\047"$\/~.]/) ok++
  }
  # One fixed-line return: count its state, judge its NEXT.
  function verdict(line,   s, v, k, m, i, vs) {
    nfixed++
    s = line; sub(/.*printf[ \t]+.%s\\n%s\\n[^ \t]*[ \t]+/, "", s)
    if (match(s, /^"[^"$]*"/)) {
      s = substr(s, 2, RLENGTH - 2)
      if (!((cur, s) in seen)) { seen[cur, s] = 1; nvoc++ }
    } else dyn = 1
    if (!match(line, /"[^"]*"[ \t;]*$/)) return
    v = substr(line, RSTART + 1, RLENGTH - 1); sub(/"[ \t;]*$/, "", v)
    if (v ~ /^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$/) {
      k = v; gsub(/[${}]/, "", k)
      m = split(substr(val[k], 2), vs, SUBSEP)
      if (m == 0) n++
      for (i = 1; i <= m; i++) judge(vs[i])
    } else judge(v)
  }
  # checks.md Check 5 requires the guard for `local`, arrays *and* `set -x`,
  # so all three mark the function -- zsh traces and word-splits every one of
  # them differently, not just `local`.
  function body(line,   t) {
    if (line ~ /(^|[^A-Za-z_])local[ \t]/) needs = 1
    if (line ~ /(^|[^A-Za-z_])set[ \t]+-[A-Za-z]*x([ \t]|$)/) needs = 1
    if (line ~ /(^|[^A-Za-z_])[A-Za-z_][A-Za-z0-9_]*\+?=\(/) needs = 1
    if (line ~ /\$\{?[A-Za-z_][A-Za-z0-9_]*\[/) needs = 1
    if (line ~ /emulate -L sh/) guarded = 1
    if (line ~ /^[^#]*(^|[^A-Za-z0-9_])ux_table_row([^A-Za-z0-9_]|$)/) tbl = 1
    # Single-quoted text (an awk/sed program), `\$1` and `${#var}` are not
    # argument reads; getopts, shift and `for x; do` read them implicitly.
    t = line; gsub(/\047[^\047"]*\047/, "", t)
    if (t ~ /^[^#]*(^|[^\\])\$(\{?[1-9@*]|#([^A-Za-z_{]|$)|\{#[@*}])/) args = 1
    if (t ~ /^[^#]*(^|[;&|[:space:]])(getopts|shift)([ \t;]|$)/) args = 1
    if (t ~ /^[^#]*(^|[;&|[:space:]])for[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*(;|do([ \t]|$)|$)/) args = 1
    if (line ~ /printf[ \t]+.%s\\n%s\\n/) verdict(line)
    network(line)
  }
  # gate[1..gd] mirrors the open if/fi stack, arm the current case arm; each
  # holds whether its condition names an opt-in token.
  function network(line,   t, tok, i, gated) {
    t = line; sub(/(^|[ \t])#.*/, "", t)
    tok = t ~ opt
    if (t ~ /(^|[;&|[:space:]])if[ \t]/) gate[++gd] = tok
    else if (gd && t ~ /(^|[;&|[:space:]])elif[ \t]/) gate[gd] = tok
    else if (gd && t ~ /(^|[;&|[:space:]])else([ \t;]|$)/) gate[gd] = 0
    if (t ~ /^[ \t]*[^ \t($="\047][^ \t=()]*\)/) arm = tok
    gated = tok || arm
    for (i = 1; i <= gd; i++) if (gate[i]) gated = 1
    if (!gated && t ~ call) net++
    if (t ~ /;;/) arm = 0
    if (gd && t ~ /(^|[;&[:space:]])fi([ \t;]|$)/) gd--
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
    nfixed = 0; nvoc = 0; dyn = 0; n = 0; ok = 0; blank = 0
    net = 0; gd = 0; arm = 0; tbl = 0; args = 0
    opened = 0
    depth = 0
    body($0)
    track($0)
    next
  }
  cur != "" { body($0); track($0) }
  END { flush() }
' "$file" "$file" 2>/dev/null || true)

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
# missed the spacing variants (`-h )`, `"--help" ]`). A `|` only continues a
# case pattern when single words separated by `|` run on to its `)`: `free -h |
# awk ...` is a pipe, not a pattern (#106). Nor is anything inside `$(...)` or
# `<(...)` (`x=$(free -h | sort)`). Glob arms (`*--help*)`, `--help=*)`,
# `-h* ]]`) still count.
help_arm='^([^#$<]|[$<][^(#])*(^|[^-[:alnum:]_])(-h|--help)[*=]*["'"'"']?(([[:space:]]*[|][[:space:]]*[^[:space:]|)]+)*[[:space:]]*[)]|[[:space:]]*])'
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
# A thin wrapper hands "$@" to another executable -- `"$_exe" "$@"` or
# `.../x.sh "$@"` (dotfiles#2195) -- so its --help lives in that file (#104).
# The call may carry env assignments (`VAR="$x" "$_exe" "$@"`) or run the
# target through an interpreter (`bash|sh|zsh "$script" "$@"`) -- issue #106.
# Every such call is judged: a `$var` target resolves through the nearest
# assignment above the call, so `local script=...` reused across functions
# (mytool's install_*) points each call at its own file. The target's literal
# tail (after the last `}` / `$VAR`) is looked up under each ancestor directory
# of the audited file, nearest first, stopping at the file's git top level when
# it has one (else at /).
# shortcut: a one-line var assignment only; widen when a wrapper builds its
# path over several lines.
# resolve_deleg <line-number> <expr> -> the target file, or nothing.
resolve_deleg() {
  _tgt=$(printf '%s' "$2" | tr -d '"')
  if printf '%s' "$_tgt" | grep -qE '^\$\{?[A-Za-z_][A-Za-z0-9_]*\}?$'; then
    _v=$(printf '%s' "$_tgt" | tr -d '${}')
    # Nearest assignment above the call; else the first one anywhere (a
    # top-level `_exe=` below the function definitions).
    _asg=$(head -n "$1" "$file" | grep -E "(^|[[:space:]])$_v=" | tail -1 || true)
    [ -n "$_asg" ] || _asg=$(grep -E "(^|[[:space:]])$_v=" "$file" | head -1 || true)
    _tgt=$(printf '%s\n' "$_asg" |
      sed -E "s/.*(^|[[:space:]])$_v=//; s/[[:space:]]+#.*//; s/[[:space:];]+\$//" | tr -d "\"'" || true)
  fi
  _tail=$(printf '%s' "$_tgt" | sed -E 's/.*\}//; s/^\$[A-Za-z_][A-Za-z0-9_]*//')
  # A literal absolute path is the target itself, never a tail to re-root.
  case $_tgt in
    /*) if [ "$_tail" = "$_tgt" ]; then
          [ ! -f "$_tgt" ] || printf '%s\n' "$_tgt"
          return 0
        fi ;;
  esac
  [ -n "$_tail" ] || return 0
  _d=$file_dir
  while :; do
    if [ -f "$_d/${_tail#/}" ]; then printf '%s\n' "$_d/${_tail#/}"; return 0; fi
    [ "$_d" != / ] && [ "$_d" != "$file_top" ] || return 0
    _d=$(dirname "$_d")
  done
}
deleg='' deleg_nohelp='' deleg_lost=''
arm=0; if has "$help_arm"; then arm=1; fi
if [ "$arm" -eq 0 ]; then
  # Resolved once, not per call: every call walks up from the same file.
  file_dir=$(CDPATH='' cd -- "$(dirname "$file")" && pwd)
  file_top=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null || echo /)
  lead='^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*)?(exec[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=("[^"]*"|[^[:space:]"]*)[[:space:]]+)*((ba|z)?sh[[:space:]]+)?'
  calls=$(grep -nE "$lead"'("?\$\{?[A-Za-z_][A-Za-z0-9_]*\}?"?|[^[:space:]]*/[^[:space:]]+)[[:space:]]+"\$@"' "$file" 2>/dev/null || true)
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    ln=${c%%:*}
    dexpr=$(printf '%s\n' "${c#*:}" | sed -E "s/$lead//"'; s/[[:space:]]+"\$@".*//')
    t=$(resolve_deleg "$ln" "$dexpr")
    if [ -z "$t" ]; then
      [ -n "$deleg_lost" ] || deleg_lost=$dexpr
    # -I: a compiled binary target (`/usr/bin/git "$@"`) is not grepped as text.
    elif ! grep -qIE -e "$help_arm" "$t" 2>/dev/null; then
      [ -n "$deleg_nohelp" ] || deleg_nohelp=$t
    else
      [ -n "$deleg" ] || deleg=$t
    fi
  done <<CALLS
$calls
CALLS
fi
# Who Check 6 asks for --help (#106): public (no leading `_`) functions that
# read their arguments, minus `*_help` renderers -- asking a help function for
# --help is circular. A sourced file with none of them has no command to check;
# that N/A only replaces the FAIL, so help a file does handle still scores.
read -r pub cand <<PUB
$(printf '%s\n' "$FUNCS" | awk -F'\t' '$1 != "" && $1 !~ /^_/ { p++; if ($1 !~ /_help$/ && $10 == 1) c++ } END { print p+0, c+0 }')
PUB
# The N/A is only safe when FUNCS saw every definition -- not `function f {`,
# an indented or a hyphenated `f-x()` -- no alias exposes a _private function
# as the public command, and the file is no tools/custom entrypoint (executed).
defs=$(count '^[[:space:]]*(function[[:space:]]+[A-Za-z_]|[A-Za-z_][-A-Za-z0-9_:]*[[:space:]]*\(\))')
na_ok=0
if [ "$sourced" -eq 1 ] && [ "$custom_entry" -eq 0 ] && [ "$defs" -le "$nfunc" ] &&
  ! has '^[[:space:]]*alias[[:space:]]+[^=]+=["'"'"']?_'; then
  na_ok=1
fi
if [ -n "$deleg_nohelp" ]; then
  r6=FAIL; n6="delegates to $deleg_nohelp, which has no -h/--help handling"
elif [ -n "$deleg" ]; then
  # An unresolvable call beside a resolved one (`"$EDITOR" "$@"`) is no wrapper.
  r6=PASS; n6="delegates --help to $deleg"
elif [ -n "$deleg_lost" ]; then
  r6=FAIL; n6="no -h/--help handling, delegate target $deleg_lost not found"
elif [ "$arm" -eq 1 ] && [ "$help_fn" -eq 1 ]; then
  r6=PASS; n6='-h/--help delegates to a help function'
elif [ "$arm" -eq 1 ]; then
  r6=WARN; n6='help handled inline, not via a help function'
elif [ "$na_ok" -eq 1 ] && [ "$pub" -eq 0 ]; then
  r6='N/A'; n6='no public command'
elif [ "$na_ok" -eq 1 ] && [ "$cand" -eq 0 ]; then
  r6='N/A'; n6='no public command takes arguments (help renderers excluded)'
else
  r6=FAIL; n6='no -h/--help handling'
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

# ---------- Check 9: Verdict Output ----------
# The gwt contract (checks.md Check 9): a *status/*verdict function returns
# fixed lines via printf '%s\n%s\n%s\n' (state / age / next), switches on a
# state vocabulary with `case`, is rendered by a separate caller through
# $(...), documents its first-match priority as `a > b > c`, and calls the
# network only behind an opt-in flag (FUNCS column 8).
# A function with no fixed-line printf is a help renderer, not a verdict, when
# it calls ux_table_row (`_gwt_help_rows_status`) or is named *_help_* (the
# `_ssl_help_rows_status` that prints ux_success lines) -- issue #104.
vfn=$(printf '%s\n' "$FUNCS" | awk -F'\t' '$1 ~ /status|verdict/ && !($4 == "-" && ($9 == 1 || $1 ~ /(^|_)help_/)) { print $1; exit }')
lines2="printf '%s\\\\n%s\\\\n"
if [ -z "$vfn" ]; then
  r9='N/A'; n9='no status/verdict function'
elif ! has "$lines2"; then
  r9=FAIL; n9="$vfn returns no fixed-line verdict"
else
  missing=''
  has "${lines2}%s\\\\n'" || missing="$missing, 3-line return"
  has 'case "?\$\{?[A-Za-z0-9_]*(state|status|verdict)' || missing="$missing, state case"
  has '\$\([A-Za-z0-9_]*(status|verdict)' || missing="$missing, separate renderer"
  has '^[[:space:]]*#.*[a-z-]+ > [a-z-]+ > [a-z-]+' || missing="$missing, priority comment"
  # Network is opt-in: an ungated call in a fixed-line verdict function.
  netfns=$(printf '%s\n' "$FUNCS" | awk -F'\t' '$4 != "" && $4 != "-" && $8 > 0 { s = s sep $1; sep = ", " } END { print s }')
  [ -z "$netfns" ] || missing="$missing, network opt-in ($netfns)"
  if [ -z "$missing" ]; then
    r9=PASS; n9='3-line verdict, state case, split render'
  else
    r9=WARN; n9="missing:${missing#,}"
  fi
fi

# ---------- Check 10: Next-action Hint ----------
# NEXT is the last argument of each fixed-line printf, judged per function in
# the FUNCS pass above; here the per-function counts are summed.
if [ -z "$vfn" ]; then
  r10='N/A'; n10='no status/verdict function'
else
nx=$(printf '%s\n' "$FUNCS" | awk -F'\t' '
  { n += $5; ok += $6; blank += $7 }
  END { printf "%d %d %d\n", n, ok, blank }')
set -- $nx
nx_n=$1 nx_ok=$2 nx_blank=$3
if [ "$nx_n" -eq 0 ]; then
  r10=FAIL; n10='verdict returns no next value'
elif [ "$nx_blank" -gt 0 ]; then
  r10=WARN; n10="$nx_blank blank NEXT, use - for terminal states"
elif [ "$nx_ok" -eq "$nx_n" ]; then
  r10=PASS; n10="all $nx_n NEXT value(s) command-shaped"
else
  r10=WARN; n10="$((nx_n - nx_ok)) of $nx_n NEXT value(s) not a command"
fi
fi

# ---------- Safety Checks 11-14 ----------
# Runtime safety, judged apart from the 10-point score (issue #108): the rows
# never reach `pass`/`fail`, so a Safety result cannot move the Verdict.
# Criteria: references/checks.md "Safety Checks".
#
# One awk pass builds, per logical line (a trailing `\` or an open quote joins
# physical lines), two views of equal length, so an offset found in one is valid
# in the other:
#   c  the code: comments and heredoc bodies dropped (an unclosed heredoc runs to
#      end of file, so its rows lean N/A -- a miss over a false alarm).
#   m  c with quoted literal text replaced by dots. Expansions survive (`$x`,
#      `${x%/*}`, `$(...)`) and so does a `/tmp/` that opens a string; a mention
#      in a help string is then no call, and every quoted word is one token.
# Commands are matched on m in command position; trap bodies are read from c,
# since a trap's code is a quoted string. Facts are collected per line and judged
# at END, because a cleanup function usually sits above the mktemp it cleans.
# ponytail: text patterns, not a parser -- `eval`, a command held in a variable
# and a cleanup reached through a `"$1"` argument stay unseen; widen on a real
# miss (issue #108 Decisions: 12 and 14 cap at WARN for that reason).
safety_sh=0
if printf '%s\n' "$shebang" | grep -qE '^#! ?(/usr)?/bin/(env +)?(da)?sh([[:space:]]|$)'; then safety_sh=1; fi
SAFETY=$(LC_ALL=C awk -v sourced="$sourced" -v posix="$safety_sh" '
  function put(s) { M = M s; C = C s }
  function dots(n,   s) { while (n-- > 0) s = s "."; return s }
  function hide(s) { C = C s; M = M dots(length(s)) }
  function brace_end(s, i,   d, c, n) {
    d = 0; n = length(s)
    for (; i <= n; i++) {
      c = substr(s, i, 1)
      if (c == "{") d++
      else if (c == "}" && --d == 0) return i
    }
    return n
  }
  # st[sp]: N plain, S single-quoted, D double-quoted, C $(...), B `...`, A $((...)).
  function scan(l,   i, n, c, d, s, e, t) {
    n = length(l); i = 1; cont = 0
    while (i <= n) {
      c = substr(l, i, 1); d = substr(l, i + 1, 1); s = st[sp]
      if (s == "S") {
        if (c == "\047") { sp--; put(c) } else hide(c)
        i++; continue
      }
      if (s == "A") {
        if (c == "(") { dp[sp]++; put(c) }
        else if (c != ")") hide(c)
        else if (dp[sp] > 0) { dp[sp]--; put(c) }
        else { sp--; put(c); if (d == ")") { put(d); i++ } }
        i++; continue
      }
      if (c == "\\") {
        if (i == n && s != "D") { cont = 1; break }
        if (s == "D") hide(c d); else put(c d)
        i += 2; continue
      }
      if (c == "$" && d == "{") {
        e = brace_end(l, i + 1); put(substr(l, i, e - i + 1)); i = e + 1
        continue
      }
      if (c == "$" && d == "(") {
        if (substr(l, i + 2, 1) == "(") { st[++sp] = "A"; put("$(("); i += 3 }
        else { st[++sp] = "C"; put("$("); i += 2 }
        dp[sp] = 0
        continue
      }
      if (s == "D") {
        if (c == "\"") { sp--; put(c) }
        else if (c == "`") { st[++sp] = "B"; put(c) }
        else if (c == "$" && d ~ /[A-Za-z_]/) {
          t = substr(l, i + 1); match(t, /^[A-Za-z0-9_]+/)
          put(substr(l, i, RLENGTH + 1)); i += RLENGTH
        } else hide(c)
        i++; continue
      }
      # `(( ))` is arithmetic like `$(( ))`: its <<, > and & are operators.
      if (c == "(" && d == "(") {
        st[++sp] = "A"; dp[sp] = 0; put("(("); i += 2
        continue
      }
      if (c == "\047" || c == "\"") {
        st[++sp] = (c == "\"") ? "D" : "S"; put(c); i++
        if (substr(l, i, 5) == "/tmp/") { put("/tmp/"); i += 5 }
        continue
      }
      if (c == "`") {
        if (s == "B") sp--; else st[++sp] = "B"
        put(c); i++; continue
      }
      if (c == "#" && (i == 1 || substr(l, i - 1, 1) ~ /[ \t;&|()]/)) break
      if (c == "<" && d == "<") {
        if (substr(l, i + 2, 1) == "<") { put("<<<"); i += 3; continue }
        t = substr(l, i + 2)
        if (match(t, /^-?[ \t]*(\047[^\047]*\047|"[^"]*"|\\?[A-Za-z_][A-Za-z0-9_.-]*)/)) {
          e = substr(t, 1, RLENGTH)
          hs[++hn] = (e ~ /^-/)
          sub(/^-?[ \t]*/, "", e); gsub(/[\047"\\]/, "", e)
          hd[hn] = e
          put(substr(l, i, RLENGTH + 2)); i += RLENGTH + 2
          continue
        }
      }
      if (s == "C") {
        if (c == "(") dp[sp]++
        else if (c == ")") { if (dp[sp] > 0) dp[sp]--; else sp-- }
      }
      put(c); i++
    }
  }
  function has_cmd(text, what) { return text ~ (pre what) }
  # The argument words of a command: up to the next operator, no redirections.
  function args_of(s) {
    sub(/[;|&)].*/, "", s)
    sub(/[ \t][0-9]*[<>].*/, "", s)
    return s
  }
  # Every $name in s goes into arr.
  function vars_into(s, arr,   t) {
    while (match(s, /\$\{?[A-Za-z_][A-Za-z0-9_]*/)) {
      t = substr(s, RSTART, RLENGTH); gsub(/[${]/, "", t)
      arr[t] = 1
      s = substr(s, RSTART + RLENGTH)
    }
  }
  # head_var "$x/y" -> x, the variable a token starts with; else nothing.
  function head_var(t) {
    gsub(/"/, "", t)
    if (!match(t, /^\$\{?[A-Za-z_][A-Za-z0-9_]*/)) return ""
    t = substr(t, 1, RLENGTH); gsub(/[${]/, "", t)
    return t
  }
  # A variable known to hold a temp path; "" (no variable) is in neither set.
  function is_tmp(h) { return (h in mk) || (h in tmpv) }
  function note_alias(lhs, rhs) {
    if (rhs !~ /\$/) return
    al[++an] = lhs; ar[an] = rhs; ah[an] = head_var(rhs)
  }
  # counted: an rm in the audited code, not one read from a trap body.
  function note_rm(text, counted,   t, n, w, i, flag, path) {
    t = text
    while (match(t, rm_re)) {
      t = substr(t, RSTART + RLENGTH)
      n = split(args_of(t), w, /[ \t]+/); flag = 0; path = ""
      anyrm = 1
      for (i = 1; i <= n; i++) {
        if (w[i] == "" || w[i] == "--") continue
        if (w[i] ~ /^-/) {
          if (w[i] ~ /^-[A-Za-z]*[rRf]/ || w[i] ~ /^--(recursive|force)/) flag = 1
          continue
        }
        path = path " " w[i]
        vars_into(w[i], removed)
      }
      if (counted && flag && inscope) { nrm++; rmargs[nrm] = path }
    }
  }
  function note_mv(m,   t, n, w, i, k, tok) {
    t = m
    while (match(t, mv_re)) {
      t = substr(t, RSTART + RLENGTH)
      n = split(args_of(t), w, /[ \t]+/); k = 0
      for (i = 1; i <= n; i++)
        if (w[i] != "" && w[i] != "--" && w[i] !~ /^-/) tok[++k] = w[i]
      if (k < 2) continue
      nmv++; mvs[nmv] = tok[1]; mvd[nmv] = tok[k]; mvtok[tok[1]] = 1
    }
  }
  function note_redirects(m, c,   t, i, n, p, a, b, rest) {
    t = m
    while (match(t, /\\./)) t = substr(t, 1, RSTART - 1) ".." substr(t, RSTART + 2)
    # `[[ $a > $b ]]` compares strings; the blank keeps the offsets into c.
    while (match(t, /\[\[.*\]\]/))
      t = substr(t, 1, RSTART - 1) dots(RLENGTH) substr(t, RSTART + RLENGTH)
    n = length(t)
    for (i = 1; i <= n; i++) {
      if (substr(t, i, 1) != ">") continue
      a = substr(t, i + 1, 1); b = (i > 1) ? substr(t, i - 1, 1) : ""
      if (a == ">") { i++; continue }
      if (a == "&" || a == "(" || b == "<" || b == "-" || b == "=") continue
      p = i + 1
      if (substr(t, p, 1) == "|") p++
      while (p <= n && substr(t, p, 1) ~ /[ \t]/) p++
      rest = substr(t, p)
      if (!match(rest, /^[^ \t;|&<>)]+/)) continue
      tn++; tm[tn] = substr(rest, 1, RLENGTH); tc[tn] = substr(c, p, RLENGTH)
      i = p + RLENGTH - 1
    }
  }
  # Each `trap body SIG...` on the line; the body comes from c, the signals from m.
  function note_traps(m, c,   p, n, q, e, body, rest, k, w, i, sig) {
    p = 1
    while (match(substr(m, p), trap_re)) {
      p += RSTART + RLENGTH - 1
      if (substr(m, p, 3) == "-- ") p += 3
      q = substr(c, p, 1); body = ""
      if (q == "\047") {
        e = index(substr(c, p + 1), "\047")
        if (!e) return
        body = substr(c, p + 1, e - 1); p += e + 1
      } else if (q == "\"") {
        n = length(c)
        for (e = p + 1; e <= n; e++) {
          if (substr(c, e, 1) == "\\") { e++; continue }
          if (substr(c, e, 1) == "\"") break
        }
        body = substr(c, p + 1, e - p - 1); p = e + 1
      } else {
        rest = substr(m, p)
        if (!match(rest, /^[^ \t;|&)]+/)) return
        body = substr(rest, 1, RLENGTH); p += RLENGTH
        if (body == "-" || body ~ /^-[a-zA-Z]/) continue
      }
      if (body ~ /^[ \t\n]*$/) continue
      # Each line of a multi-line body starts a command.
      gsub(/\n/, ";", body)
      note_rm(body, 0)
      note_assigns(body)
      rest = substr(m, p); sub(/[;&|)}].*/, "", rest)
      k = split(rest, w, /[ \t]+/)
      for (i = 1; i <= k; i++) {
        sig = toupper(w[i]); sub(/^SIG/, "", sig)
        if (sig == "0" || sig == "EXIT") { t_exit = 1; b_exit = b_exit ";" body }
        else if (sig == "2" || sig == "INT") { t_int = 1; b_sig = b_sig ";" body }
        else if (sig == "15" || sig == "TERM") { t_term = 1; b_sig = b_sig ";" body }
      }
    }
  }
  function note_mktemp(m, c,   t, off, name, rest, got) {
    if (!has_cmd(m, "mktemp([ \t;|&)`]|$)")) return 0
    t = m; off = 0; got = 0
    while (match(t, /[A-Za-z_][A-Za-z0-9_]*="?(\$\(|`)[^;|&)]*mktemp/)) {
      name = substr(t, RSTART, RLENGTH); sub(/=.*/, "", name)
      off += RSTART + RLENGTH - 1
      rest = substr(c, off + 1); sub(/[;|].*/, "", rest)
      if (!(name in mk)) mkorder[++mkn] = name
      mk[name] = mk[name] " " rest
      got = 1
      t = substr(t, RSTART + RLENGTH)
    }
    if (!got) unnamed++
    return 1
  }
  function note_assigns(m,   t, lhs, rhs, n, w, i) {
    t = m
    while (match(t, assign_re)) {
      lhs = substr(t, RSTART, RLENGTH); gsub(/[^A-Za-z0-9_]/, "", lhs)
      t = substr(t, RSTART + RLENGTH)
      if (substr(t, 1, 1) == "(") match(t, /^[^)]*/)
      else match(t, /^[^ \t;|&]*/)
      rhs = substr(t, 1, RLENGTH)
      if (rhs ~ /dirname|%\//) dirvar[lhs] = 1
      if (rhs ~ /^\(/) {
        n = split(substr(rhs, 2), w, /[ \t]+/)
        for (i = 1; i <= n; i++) note_alias(lhs, w[i])
      } else note_alias(lhs, rhs)
    }
    if (match(m, /(^|[ \t;&|(])for[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]+in[ \t]/)) {
      lhs = substr(m, RSTART, RLENGTH); sub(/^.*for[ \t]+/, "", lhs); sub(/[ \t].*/, "", lhs)
      t = substr(m, RSTART + RLENGTH); sub(/;.*/, "", t)
      n = split(t, w, /[ \t]+/)
      for (i = 1; i <= n; i++) note_alias(lhs, w[i])
    }
  }
  # Option handling (Check 14): an arm or test naming the flag, then the variable
  # it sets -- the assignments up to the end of that arm or if.
  function note_flags(m, c,   hit, t, name) {
    if (c ~ /getopts[ \t]+["\047]?:?[A-Za-z:]*n([^:]|$)/) gopt = 1
    hit = (c ~ arm_re || (gopt && c ~ /^[ \t]*[(]?n[)]/)) ? 1 : (c ~ test_re) ? 2 : 0
    # `-n|--name)` or `-n) n=$2`: a value option that only shares the letter.
    if (hit == 1 && c !~ /--dry-run|--apply/ && c ~ /(^|[ \t(|])--[a-z]|[$][{]?2|OPTARG/) hit = 0
    if (hit) {
      flagged = 1; ftest = (hit == 2); fvar = 0
      fwin = (hit == 1) ? 4 : (m ~ /then[ \t]*$/) ? 2 : 1
    }
    if (fwin <= 0) return
    t = m
    while (match(t, assign_re)) {
      name = substr(t, RSTART, RLENGTH); gsub(/[^A-Za-z0-9_]/, "", name)
      flagvar[name] = 1; fvar = 1
      t = substr(t, RSTART + RLENGTH)
    }
    fwin--
    if (m ~ /;;|(^|[ \t;])fi([ \t;]|$)/) fwin = 0
    # A bare test gates the code itself: the option is read where it is parsed.
    if (fwin == 0 && ftest && !fvar) direct = 1
  }
  function analyze(m, c,   t, o, e) {
    ln++
    if (m ~ /^[ \t]*(function[ \t]+)?[A-Za-z_][A-Za-z0-9_-]*[ \t]*\(\)/ ||
        m ~ /^[ \t]*function[ \t]+[A-Za-z_]/) {
      if (cur == "" || !opened) {
        t = m; sub(/^[ \t]*(function[ \t]+)?/, "", t); match(t, /^[A-Za-z0-9_-]+/)
        cur = substr(t, 1, RLENGTH); depth = 0; opened = 0
      }
    }
    if (cur != "") {
      # Joined by `;`, not a newline: the ^ in pre matches only at string start.
      fbody[cur] = fbody[cur] ";" m
      t = m; o = gsub(/[{]/, "", t)
      t = m; e = gsub(/[}]/, "", t)
      if (o > 0) opened = 1
      depth += o - e
    }
    inscope = !sourced || (cur != "" && cur !~ /^_/)
    if (!note_mktemp(m, c) && (match(m, tmp_asg_re) || match(m, tmp_red_re))) {
      t = substr(c, RSTART + RLENGTH - 5)
      if (t ~ /^\/tmp\// && t !~ /XXX/) {
        sub(/[ \t\n;|&"\047)].*/, "", t)
        if (nfixed++ == 0) fixed = t
      }
    }
    note_traps(m, c)
    note_rm(m, 1)
    note_mv(m)
    # A function printing the path hands it to its caller (`_mk_temp`), which
    # owns the cleanup; a file-level print is no hand-off.
    if (cur != "" && match(m, /(echo|printf[ \t]+[^ \t]+)[ \t]+"?\$\{?[A-Za-z_][A-Za-z0-9_]*\}?"?[ \t]*(;|$)/))
      vars_into(substr(m, RSTART, RLENGTH), removed)
    note_redirects(m, c)
    note_assigns(m)
    note_flags(m, c)
    if (inscope) {
      if (has_cmd(m, git_re "push([ \t;|&)]|$)")) mutate("git push")
      if (has_cmd(m, git_re "reset[ \t]([^;|&]*[ \t])?--hard")) mutate("git reset --hard")
      if (has_cmd(m, "sudo[ \t]")) mutate("sudo")
      if (has_cmd(m, "gh[ \t]+((-R|--repo)[ \t]+[^ \t]+[ \t]+)?[a-z-]+[ \t]+(create|merge|delete)([ \t;|&)]|$)")) mutate("gh write")
    }
    if (m ~ cond_re || m ~ /&&|[|][|]/) cond = cond "\n" m
    if (m ~ /^[ \t]*disown([ \t;]|$)/ && lastbg && ln - lastbg <= 2) { nbg--; lastbg = 0 }
    t = m
    gsub(/\\./, "", t); gsub(/\$\{[^}]*\}/, "", t); gsub(/&&|[<>;]&|&>|[|]&/, "", t)
    if (t ~ /&/ && m !~ /(^|[^A-Za-z0-9_-])(nohup|disown|setsid)([^A-Za-z0-9_-]|$)/) {
      nbg++; lastbg = ln
    }
    if (cur != "" && opened && depth <= 0) cur = ""
  }
  function mutate(what) { nmut++; if (first == "") first = what }
  # text plus, transitively, the bodies of the functions it names.
  function reach(text, d,   n, w, i, out) {
    out = text
    if (d >= 5) return out
    n = split(text, w, /[^A-Za-z0-9_-]+/)
    for (i = 1; i <= n; i++)
      if ((w[i] in fbody) && !(w[i] in seen)) {
        seen[w[i]] = 1
        out = out ";" reach(fbody[w[i]], d + 1)
      }
    return out
  }
  function row(id, r, note) {
    printf "safety\t%d\t%s\t%s\n", id, r, note
    if (r == "PASS") sp_pass++
    if (r != "N/A") sp_eff++
  }
  BEGIN {
    pre = "(^|[;&|(){!`]|(if|elif|while|until|then|do|else|exec|command|sudo|xargs|env|time)[ \t])[ \t]*(\\\\)?([A-Za-z_][A-Za-z0-9_]*=[^ \t]*[ \t]+)*"
    rm_re = pre "rm[ \t]+"
    mv_re = pre "mv[ \t]+"
    trap_re = pre "trap[ \t]+"
    git_re = "git[ \t]+(-[Cc][ \t]+[^ \t]+[ \t]+)*"
    assign_re = "(^|[ \t;&|(){])[A-Za-z_][A-Za-z0-9_]*[+]?="
    tmp_asg_re = "(^|[ \t;&|(])[A-Za-z_][A-Za-z0-9_]*=[\"\047]?/tmp/"
    tmp_red_re = ">[>|]?[ \t]*[\"\047]?/tmp/"
    cond_re = "(^|[;&|(!{ \t])(if|elif|while|until|case|test|\\[|\\[\\[)[ \t]"
    arm_re = "(^|[ \t]in[ \t]|;;)[ \t]*[(]?[ \t]*([^ \t|)]+[ \t]*[|][ \t]*)*[\"\047]?(--dry-run|--apply|-n)(=[^ \t|)]*)?[\"\047]?[ \t]*[|)]"
    test_re = "=[=]?[ \t]*[\"\047]?(--dry-run|--apply|-n)[\"\047]?[ \t]*\\]"
    st[0] = "N"
  }
  hn > hi {
    l = $0
    if (hs[hi + 1]) sub(/^\t+/, "", l)
    if (l == hd[hi + 1]) { hi++; if (hi == hn) hi = hn = 0 }
    next
  }
  {
    scan($0)
    if (cont) next
    if (st[sp] == "S" || st[sp] == "D") { hide("\n"); next }
    analyze(M, C)
    M = ""; C = ""
  }
  END {
    if (M != "" || C != "") analyze(M, C)
    # Aliases: a variable holding a temp path is one too, and removing it counts.
    for (i = 1; i <= nmv; i++) {
      h = head_var(mvs[i])
      if (h != "") removed[h] = 1
    }
    for (pass_n = 0; pass_n < 4; pass_n++)
      for (i = 1; i <= an; i++) {
        if (is_tmp(ah[i])) tmpv[al[i]] = 1
        if (al[i] in removed) vars_into(ar[i], removed)
      }

    # ----- 11 Temp File Cleanup
    unrem = ""
    for (i = 1; i <= mkn; i++) {
      name = mkorder[i]
      if (name in removed) continue
      split("", parents); vars_into(mk[name], parents); inner = 0
      for (p in parents) if ((p in mk) && (p in removed)) inner = 1
      if (!inner && unrem == "") unrem = name
    }
    split("", seen)
    exit_rm = (reach(b_exit, 0) ~ rm_re)
    if (mkn + unnamed + nfixed == 0) row(11, "N/A", "no mktemp or /tmp path")
    else if (nfixed) row(11, "FAIL", "predictable temp path " fixed)
    else if (unrem != "") row(11, "FAIL", "mktemp result $" unrem " is never removed")
    else if (unnamed && !anyrm && !mkn) row(11, "FAIL", "mktemp result is never removed")
    else if (sourced && t_exit) row(11, "WARN", "sourced fragment sets an EXIT trap, overriding the caller")
    else if (sourced) row(11, "PASS", "mktemp result removed, no EXIT trap in a sourced fragment")
    else if (exit_rm) row(11, "PASS", "mktemp paths only, rm reached from the EXIT trap")
    else row(11, "WARN", "no rm in an EXIT trap, early exit leaks the temp path")

    # ----- 12 Atomic Write
    direct_n = 0; sample = ""
    for (i = 1; i <= tn; i++) {
      t = tc[i]; gsub(/"|\047/, "", t)
      if (t ~ /^\/dev\// || t ~ /^\/tmp\//) continue
      if (is_tmp(head_var(tm[i])) || (tm[i] in mvtok)) continue
      if (direct_n++ == 0) sample = t
    }
    mv_same = 0; mv_cross = 0
    for (i = 1; i <= nmv; i++) {
      h = head_var(mvs[i])
      if (!is_tmp(h)) continue
      tpl = (h in mk) ? mk[h] : ""
      same = (tpl ~ /dirname|%\//)
      split("", parents); vars_into(tpl, parents)
      d = head_var(mvd[i])
      for (p in parents) if ((p in dirvar) || p == d) same = 1
      if (same) mv_same++; else mv_cross++
    }
    if (direct_n + mv_same + mv_cross == 0) row(12, "N/A", "no overwriting redirect or mktemp + mv")
    else if (direct_n) row(12, "WARN", direct_n " direct > overwrite(s), first " sample)
    else if (mv_cross) row(12, "WARN", "mv from a default mktemp template may cross filesystems")
    else row(12, "PASS", "same-directory mktemp + mv")

    # ----- 13 Signal Handling
    split("", seen)
    clean = reach(b_exit ";" b_sig, 0)
    both = t_int && t_term
    if (nbg == 0 && !(posix && t_exit)) row(13, "N/A", "no unmanaged background job or sh EXIT trap")
    else if (nbg && !t_int && !t_term) row(13, "FAIL", nbg " background job(s), no INT/TERM trap")
    else if (!both && (t_int || t_term)) row(13, "WARN", "trap names only " (t_int ? "INT" : "TERM"))
    else if (!both) row(13, "WARN", "#!/bin/sh EXIT trap alone may not run on SIGTERM")
    else if (nbg && !has_cmd(clean, "(kill|wait)([ \t;|&)]|$)")) row(13, "WARN", "INT/TERM trapped but no kill or wait in the cleanup path")
    else row(13, "PASS", "INT and TERM trapped")

    # ----- 14 Dry-run Support
    for (i = 1; i <= nrm; i++) {
      n = split(rmargs[i], w, /[ \t]+/); only_tmp = 0; other = 0
      for (j = 1; j <= n; j++) {
        if (w[j] == "") continue
        if (is_tmp(head_var(w[j]))) only_tmp = 1
        else other = 1
      }
      if (!only_tmp || other) mutate("rm")
    }
    if (nmut == 0) row(14, "N/A", "no mutating command in scope")
    else {
      # A flag handed to a function arrives under another name (`_run 1`, then
      # `local dry_run="$1"`), so any *dry*/*apply* variable in a condition counts.
      read = direct || cond ~ /\$\{?[A-Za-z0-9_]*([Dd][Rr][Yy]|[Aa][Pp][Pp][Ll][Yy])/
      for (v in flagvar) if (cond ~ ("\\$\\{?" v "([^A-Za-z0-9_]|$)")) read = 1
      if (flagged && read) row(14, "PASS", "dry-run flag parsed and read in a condition")
      else if (flagged) row(14, "WARN", "dry-run flag parsed but never read in a condition")
      else row(14, "WARN", nmut " mutating command(s), first " first ", no --dry-run/--apply")
    }
    printf "safety-score\t%d/%d\n", sp_pass, sp_eff
  }
' "$file" 2>/dev/null || true)

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
out 9 "$r9" "$n9"
out 10 "$r10" "$n10"

# Per-verdict-function table (issue #39): one row per function with a
# fixed-line return, so a large file cannot bury its status function's quality
# in the file score. Informational only -- it never enters the score.
printf '%s\n' "$FUNCS" | awk -F'\t' -v OFS='\t' '
  $4 == "" || $4 == "-" { next }
  {
    r = $5 == 0 ? "FAIL" : ($4 == "?" || $7 > 0 || $6 < $5) ? "WARN" : "PASS"
    print "fn", $1, $4, $6 "/" $5, r
  }'

# Safety rows (issue #108): printed with or without the judgments, right after
# the fn rows, and never counted into the score below.
printf '%s\n' "$SAFETY"

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
