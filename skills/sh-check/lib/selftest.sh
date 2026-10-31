#!/bin/sh
# selftest.sh -- one runnable check for sh_check.sh. Builds throwaway fixtures
# and asserts the contracts in that helper's header. Run: sh lib/selftest.sh

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
# verdict <output> -> the verdict column of the score row
verdict() { printf '%s\n' "$1" | awk -F'\t' '$1 == "score" { print $3 }'; }
# fnrows <output> -> the per-verdict-function table rows, tag dropped
fnrows() { printf '%s\n' "$1" | awk -F'\t' -v OFS=' ' '$1 == "fn" { $1 = ""; print substr($0, 2) }'; }
# safety <file> <check-id> -> the result column of that file's Safety row;
# safety_note the note column. The executable bit decides the class, so fixtures
# meant as scripts are chmod +x (scr writes one).
safety() { sh "$here/sh_check.sh" "$1" | awk -F'\t' -v id="$2" '$1 == "safety" && $2 == id { print $3 }'; }
safety_note() { sh "$here/sh_check.sh" "$1" | awk -F'\t' -v id="$2" '$1 == "safety" && $2 == id { print $4 }'; }
safety_score() { sh "$here/sh_check.sh" "$1" | awk -F'\t' '$1 == "safety-score" { print $2 }'; }
# scr <path> -- stdin becomes an executed script; frag <path> a sourced fragment.
scr() { cat > "$1"; chmod +x "$1"; }
frag() { cat > "$1"; chmod -x "$1"; }

# ---------- fixture 1: a clean sourced shell-common function ----------
mkdir -p "$work/dotfiles/shell-common/functions"
good=$work/dotfiles/shell-common/functions/git_worktree.sh
cat > "$good" <<'EOF'
#!/bin/sh
case $- in *i*) ;; *) [ -n "${DOTFILES_FORCE_INIT-}" ] || return 0 ;; esac

_gwt_help() {
    [ -n "${ZSH_VERSION-}" ] && emulate -L sh
    local unused=""
    ux_info "usage: gwt <cmd>"
}

gwt() {
    [ -n "${ZSH_VERSION-}" ] && emulate -L sh
    local cmd="$1"
    case "$cmd" in
        -h|--help) _gwt_help; return 0 ;;
    esac
    ux_success "done"
}
EOF
g=$(sh "$here/sh_check.sh" "$good" PASS PASS)
eq "good: 1 shebang"      "$(row "$g" 1)" PASS
eq "good: 2 guard"        "$(row "$g" 2)" PASS
eq "good: 4 naming"       "$(row "$g" 4)" PASS
eq "good: 5 zsh guard"    "$(row "$g" 5)" PASS
eq "good: 6 help flag"    "$(row "$g" 6)" PASS
eq "good: 7 ux lib"       "$(row "$g" 7)" PASS
eq "good: 9 no verdict fn" "$(row "$g" 9)" 'N/A'
eq "good: 10 no verdict fn" "$(row "$g" 10)" 'N/A'
eq "good: verdict"        "$(verdict "$g")" EXCELLENT
eq "good: no verdict function, no fn table" "$(fnrows "$g")" ''

# ---------- fixture 2: a shell-common file breaking every mechanical rule ----------
bad=$work/dotfiles/shell-common/functions/bad.sh
cat > "$bad" <<'EOF'
#!/usr/bin/env bash
doThing() {
    local x="$1"
    if [[ -n "$x" ]]; then
        echo "hi"
    fi
}
EOF
b=$(sh "$here/sh_check.sh" "$bad" FAIL FAIL)
eq "bad: 1 bash shebang in shell-common" "$(row "$b" 1)" FAIL
eq "bad: 2 no interactive guard"         "$(row "$b" 2)" FAIL
eq "bad: 4 camelCase"                    "$(row "$b" 4)" FAIL
eq "bad: 5 no emulate guard"             "$(row "$b" 5)" FAIL
eq "bad: 6 no help flag"                 "$(row "$b" 6)" FAIL
eq "bad: 7 raw echo only"                "$(row "$b" 7)" FAIL
eq "bad: verdict"                        "$(verdict "$b")" POOR

# ---------- Check 1: POSIX character classes are not [[ ]] (issue #46) ----------
cls=$work/dotfiles/shell-common/functions/cls.sh
cat > "$cls" <<'EOF'
#!/bin/sh
_gitdir() { sed -n 's/^gitdir:[[:space:]]*//p' "$1" | tr -d '[[:cntrl:]]'; }
EOF
eq "class: [[:space:]] alone is POSIX" "$(row "$(sh "$here/sh_check.sh" "$cls" PASS PASS)" 1)" PASS
printf '%s\n' '[[ -n "$1" ]] && echo hi' >> "$cls"
eq "class: real [[ ]] still FAILs in shell-common" \
  "$(row "$(sh "$here/sh_check.sh" "$cls" PASS PASS)" 1)" FAIL
mixed=$work/mixed.sh
printf '#!/bin/sh\ncase $x in *[[:digit:]]*) ;; esac\n[[ $x = [[:alpha:]]* ]]\n' > "$mixed"
eq "class: [[ ]] wrapping a class still WARNs" \
  "$(row "$(sh "$here/sh_check.sh" "$mixed" PASS PASS)" 1)" WARN
printf '#!/bin/sh\nfoo [[:upper:]] &>/dev/null\n' > "$mixed"
eq "class: &> next to a class still WARNs" \
  "$(row "$(sh "$here/sh_check.sh" "$mixed" PASS PASS)" 1)" WARN

# ---------- Check 1: an escaped \[[ in a sed regex is not [[ ]] (dotfiles#1883) ----------
esc=$work/dotfiles/shell-common/functions/esc.sh
cat > "$esc" <<'EOF'
#!/bin/sh
_strip() { sed 's/^\[[^]]*\]//' "$1"; }
EOF
eq "escape: sed \\[[ alone is POSIX" "$(row "$(sh "$here/sh_check.sh" "$esc" PASS PASS)" 1)" PASS
printf '%s\n' '[[ -n "$1" ]] && echo hi' >> "$esc"
eq "escape: real [[ ]] still FAILs in shell-common" \
  "$(row "$(sh "$here/sh_check.sh" "$esc" PASS PASS)" 1)" FAIL

# ---------- Check 1: tools/custom entrypoints are #!/bin/bash (dotfiles#1883) ----------
mkdir -p "$work/dotfiles/shell-common/tools/custom/lib"
entry=$work/dotfiles/shell-common/tools/custom/demo.sh
printf '#!/bin/bash\n[[ -n "$1" ]] && echo hi\n' > "$entry"
eq "custom: bash entrypoint PASSes" "$(row "$(sh "$here/sh_check.sh" "$entry" PASS PASS)" 1)" PASS
printf '#!/bin/sh\nexit 0\n' > "$entry"
eq "custom: sh entrypoint FAILs" "$(row "$(sh "$here/sh_check.sh" "$entry" PASS PASS)" 1)" FAIL
clib=$work/dotfiles/shell-common/tools/custom/lib/util.sh
printf '#!/bin/sh\nexit 0\n' > "$clib"
eq "custom: sh lib PASSes" "$(row "$(sh "$here/sh_check.sh" "$clib" PASS PASS)" 1)" PASS
printf '#!/bin/bash\nexit 0\n' > "$clib"
eq "custom: bash lib FAILs" "$(row "$(sh "$here/sh_check.sh" "$clib" PASS PASS)" 1)" FAIL

# ---------- N/A rows leave the denominator ----------
plain=$work/plain.sh
printf '#!/bin/sh\nexit 0\n' > "$plain"
chmod +x "$plain"   # checks.md Check 2: N/A needs the execute bit, not just #!
p=$(sh "$here/sh_check.sh" "$plain" 'N/A' 'N/A')
eq "plain: 4 no functions" "$(row "$p" 4)" 'N/A'
eq "plain: score drops N/A rows" \
  "$(printf '%s\n' "$p" | awk -F'\t' '$1 == "score" { print $2 }')" 1/2

# ---------- the verdict boundaries ----------
# mid.sh scores 4 mechanical PASS + 4 N/A (9/10 included: no verdict
# function), so the two judgments move it across the bands; bad.sh covers POOR.
mid=$work/mid.sh
cat > "$mid" <<'EOF'
#!/bin/sh
# usage: mid --help
mid_help() { ux_info "usage: mid"; }
mid() {
    case "$1" in
        -h|--help) mid_help; return 0 ;;
    esac
    ux_success "ok"
}
EOF
chmod +x "$mid"
eq "mid: 6/6 is EXCELLENT" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" PASS PASS)")" EXCELLENT
eq "mid: 5/6 no FAIL is GOOD" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" PASS WARN)")" GOOD
eq "mid: 4/6 no FAIL is NEEDS WORK" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" WARN WARN)")" 'NEEDS WORK'
eq "mid: 5/6 with one FAIL is NEEDS WORK" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" FAIL PASS)")" 'NEEDS WORK'

# ---------- Check 9/10: the gwt verdict contract (issue #36) ----------
# verdict_fixture <path> <next-of-dirty> [extra-line] -- a gwt-shaped status
# helper whose `dirty` NEXT is the second argument.
verdict_fixture() {
  cat > "$1" <<EOF
#!/bin/sh
# Priority: dirty > ahead > clean
_vt_compute_status() {
    case "\$_state" in
        dirty) printf '%s\\n%s\\n%s\\n' "dirty" "2h" "$2" ;;
        ahead) printf '%s\\n%s\\n%s\\n' "ahead" "1h" "git push" ;;
        *)     printf '%s\\n%s\\n%s\\n' "clean" "-" "-" ;;
    esac
}
_vt_render() { out=\$(_vt_compute_status); ux_info "\$out"; }
${3:-}
EOF
}
vpass=$work/vpass.sh;   verdict_fixture "$vpass" 'gwt teardown'
vprose=$work/vprose.sh; verdict_fixture "$vprose" 'commit or stash'
vblank=$work/vblank.sh; verdict_fixture "$vblank" ''
vskill=$work/vskill.sh; verdict_fixture "$vskill" '/gh-pr:create'
vfam=$work/vfam.sh;     verdict_fixture "$vfam" 'gh-flow prune 1'
vlook=$work/vlook.sh;   verdict_fixture "$vlook" 'ghost-town 1'
vcd=$work/vcd.sh;       verdict_fixture "$vcd" 'cd /tmp && gwt teardown'
vcdp=$work/vcdp.sh;     verdict_fixture "$vcdp" 'cd /tmp && review it'
vcdb=$work/vcdb.sh;     verdict_fixture "$vcdb" 'cd /tmp && '
vthen=$work/vthen.sh;   verdict_fixture "$vthen" "review 'x', then gh-flow prune 1"
v=$(sh "$here/sh_check.sh" "$vpass")
eq "vpass: 9 gwt contract" "$(row "$v" 9)" PASS
eq "vpass: 10 command-shaped NEXT, - for terminal" "$(row "$v" 10)" PASS
eq "vpass: 9/10 rows are deterministic" "$(sh "$here/sh_check.sh" "$vpass" | grep -v '^safety' | tail -2)" \
  "$(printf '%s\n' "$v" | grep -v '^safety' | tail -2)"
eq "vskill: a /plugin:skill NEXT is a command" "$(row "$(sh "$here/sh_check.sh" "$vskill")" 10)" PASS
eq "vfam: a gh-flow family NEXT is a command (issue #41)" "$(row "$(sh "$here/sh_check.sh" "$vfam")" 10)" PASS
eq "vlook: a lookalike prefix is still WARN" "$(row "$(sh "$here/sh_check.sh" "$vlook")" 10)" WARN
eq "vcd: cd X && <command> is a command (issue #47)" "$(row "$(sh "$here/sh_check.sh" "$vcd")" 10)" PASS
eq "vcdp: cd X && <prose> is still WARN" "$(row "$(sh "$here/sh_check.sh" "$vcdp")" 10)" WARN
eq "vcdb: cd X && <nothing> is still WARN" "$(row "$(sh "$here/sh_check.sh" "$vcdb")" 10)" WARN
eq "vthen: review ..., then <command> is still WARN" "$(row "$(sh "$here/sh_check.sh" "$vthen")" 10)" WARN
# Read-only commands and the gh- hyphen family are command-shaped (#106).
# (gh-pr-approve already matched the gh- family rule; pinned here.)
for c in "tail -40 '\$_dir/log'" "ls -la '\$_dir'" "cat '\$_dir/out'" 'gh-pr-approve prune 1'; do
  verdict_fixture "$work/vro.sh" "$c"
  eq "vro: '$c' NEXT is a command (issue #106)" "$(row "$(sh "$here/sh_check.sh" "$work/vro.sh")" 10)" PASS
done
# ...but prose that merely opens with one of those words stays WARN.
for c in 'tail the log until it settles' 'cat output looks wrong, investigate'; do
  verdict_fixture "$work/vro.sh" "$c"
  eq "vro: '$c' prose NEXT stays WARN" "$(row "$(sh "$here/sh_check.sh" "$work/vro.sh")" 10)" WARN
done
eq "vprose: prose NEXT is WARN, not FAIL" "$(row "$(sh "$here/sh_check.sh" "$vprose")" 10)" WARN
eq "vblank: blank NEXT is WARN" "$(row "$(sh "$here/sh_check.sh" "$vblank")" 10)" WARN

# ---------- per-verdict-function table (issue #39) ----------
vt=$(sh "$here/sh_check.sh" "$vpass" PASS PASS)
eq "vpass: fn row counts vocab and NEXT" "$(fnrows "$vt")" '_vt_compute_status 3 3/3 PASS'
eq "vpass: fn table sits right before the score row" \
  "$(printf '%s\n' "$vt" | grep -v '^safety' | tail -2 | cut -f1 | tr '\n' ' ')" 'fn score '
eq "vprose: a prose NEXT makes the fn row WARN" \
  "$(fnrows "$(sh "$here/sh_check.sh" "$vprose")")" '_vt_compute_status 3 2/3 WARN'
two=$work/two.sh
verdict_fixture "$two" 'gwt teardown' "_vt_verdict() {
    [ -n \"\$1\" ] && printf '%s\\n%s\\n%s\\n' \"done\" \"-\" \"gwt prune\"
    printf '%s\\n%s\\n%s\\n' \"done\" \"-\" \"-\"
}"
eq "two: every verdict function gets a row, repeated states counted once" "$(fnrows "$(sh "$here/sh_check.sh" "$two")")" \
  "$(printf '%s\n%s' '_vt_compute_status 3 3/3 PASS' '_vt_verdict 1 2/2 PASS')"

# A "$var" NEXT resolves to the variable's assignments (the _gh_flow_verdict shape).
vvar=$work/vvar.sh
cat > "$vvar" <<'EOF'
#!/bin/sh
# Priority: done > busy > idle
_vv_verdict() {
    case "$_state" in
        done) _action="gh pr merge 1" ;;
        *)    _action="-" ;;
    esac
    printf '%s\n%s\n%s\n' "$_state" "-" "$_action"
}
_vv_show() { v=$(_vv_verdict); ux_info "$v"; }
EOF
eq "vvar: a \$var NEXT resolves through its assignments" \
  "$(row "$(sh "$here/sh_check.sh" "$vvar")" 10)" PASS
eq "vvar: a dynamic state is vocab ? and WARN" \
  "$(fnrows "$(sh "$here/sh_check.sh" "$vvar")")" '_vv_verdict ? 2/2 WARN'

# Structure without a fixed vocabulary is WARN (Error Cases).
nocase=$work/nocase.sh
cat > "$nocase" <<'EOF'
#!/bin/sh
_nc_status() { printf '%s\n%s\n%s\n' "ok" "-" "-"; }
EOF
eq "nocase: fixed lines but no state case is WARN" \
  "$(row "$(sh "$here/sh_check.sh" "$nocase")" 9)" WARN

# A status function that only talks prose fails both.
vfree=$work/vfree.sh
cat > "$vfree" <<'EOF'
#!/bin/sh
show_status() { ux_info "looks good"; }
EOF
vf=$(sh "$here/sh_check.sh" "$vfree")
eq "vfree: prose verdict is FAIL" "$(row "$vf" 9)" FAIL
eq "vfree: no NEXT anywhere is FAIL" "$(row "$vf" 10)" FAIL

# Network is opt-in (issue #42): a gh/curl/wget call inside a fixed-line verdict
# function is WARN unless an enclosing if/case names the opt-in flag.
# net_fixture <path> <body-lines> -- vpass with extra lines before the case.
net_fixture() {
  cat > "$1" <<EOF
#!/bin/sh
# Priority: dirty > ahead > clean
_vt_compute_status() {
$2
    case "\$_state" in
        dirty) printf '%s\\n%s\\n%s\\n' "dirty" "2h" "gh pr view 1" ;;
        *)     printf '%s\\n%s\\n%s\\n' "clean" "-" "-" ;;
    esac
}
_vt_render() { out=\$(_vt_compute_status); ux_info "\$out"; }
EOF
}
net_fixture "$work/vnet.sh" '    _pr=$(gh pr view "$1" --json state)'
vn=$(sh "$here/sh_check.sh" "$work/vnet.sh")
eq "vnet: an ungated gh call in the verdict is WARN" "$(row "$vn" 9)" WARN
eq "vnet: the note names the function" \
  "$(printf '%s\n' "$vn" | awk -F'\t' '$1 == 9 { print $3 }')" \
  'missing: network opt-in (_vt_compute_status)'
net_fixture "$work/vcurl.sh" '    command -v curl >/dev/null && curl -s https://x'
eq "vcurl: curl after && is a call too" "$(row "$(sh "$here/sh_check.sh" "$work/vcurl.sh")" 9)" WARN
net_fixture "$work/vgate.sh" '    if [ "$_remote" = 1 ]; then
        _pr=$(gh pr view "$1" --json state)
    fi'
eq "vgate: a gh call behind if \$_remote is PASS" "$(row "$(sh "$here/sh_check.sh" "$work/vgate.sh")" 9)" PASS
net_fixture "$work/velse.sh" '    if [ "$_remote" = 1 ]; then
        :
    else
        wget -q https://x
    fi'
eq "velse: the else of the opt-in branch is not gated" "$(row "$(sh "$here/sh_check.sh" "$work/velse.sh")" 9)" WARN
net_fixture "$work/varm.sh" '    case "$1" in
        --remote) _pr=$(gh pr view "$2") ;;
    esac'
eq "varm: a gh call in a --remote case arm is PASS" "$(row "$(sh "$here/sh_check.sh" "$work/varm.sh")" 9)" PASS
net_fixture "$work/vprobe.sh" '    command -v gh >/dev/null 2>&1 || return 1
    # gh pr view is only named in this comment'
eq "vprobe: command -v gh, a comment and a gh NEXT string are not calls" \
  "$(row "$(sh "$here/sh_check.sh" "$work/vprobe.sh")" 9)" PASS

# ---------- regressions: PR #12 review ----------
# Two guards inside one function must not cover a second, unguarded one.
skew=$work/dotfiles/shell-common/functions/skew.sh
cat > "$skew" <<'EOF'
#!/bin/sh
case $- in *i*) ;; *) [ -n "${DOTFILES_FORCE_INIT-}" ] || return 0 ;; esac

one() {
    [ -n "${ZSH_VERSION-}" ] && emulate -L sh
    [ -n "${ZSH_VERSION-}" ] && emulate -L sh
    local a=""
    ux_info "$a"
}

two() {
    local b=""
    ux_info "$b"
}
EOF
eq "skew: guard counted per function, not file-wide" \
  "$(row "$(sh "$here/sh_check.sh" "$skew")" 5)" WARN

# State must not leak past the closing brace into the next function.
leak=$work/dotfiles/shell-common/functions/leak.sh
cat > "$leak" <<'EOF'
#!/bin/sh
case $- in *i*) ;; *) [ -n "${DOTFILES_FORCE_INIT-}" ] || return 0 ;; esac

one() {
    local a=""
    ux_info "$a"
}

# every local-using function needs [ -n "${ZSH_VERSION-}" ] && emulate -L sh
EOF
eq "leak: a line after the closing brace is not the function's guard" \
  "$(row "$(sh "$here/sh_check.sh" "$leak")" 5)" FAIL

# checks.md Check 5 names arrays and `set -x` beside `local` as guard-needing.
constructs=$work/dotfiles/shell-common/functions/constructs.sh
cat > "$constructs" <<'EOF'
#!/bin/sh
case $- in *i*) ;; *) [ -n "${DOTFILES_FORCE_INIT-}" ] || return 0 ;; esac

listy() {
    items=(one two)
    ux_info "${items[0]}"
}

traced() {
    set -x
    ux_info tracing
}
EOF
eq "constructs: arrays and set -x need the guard too" \
  "$(row "$(sh "$here/sh_check.sh" "$constructs")" 5)" FAIL

# Definitions are found whichever way the brace is placed.
braces=$work/braces.sh
cat > "$braces" <<'EOF'
#!/bin/sh
tight(){
    ux_info one
}
spaced ()
{
    ux_info two
}
oneline() { ux_info three; }
EOF
eq "braces: all three definition styles counted" \
  "$(row "$(sh "$here/sh_check.sh" "$braces")" 4)" PASS

# A shebang does not prove the file is executed rather than sourced.
aliased=$work/aliased.sh
cat > "$aliased" <<'EOF'
#!/bin/sh
alias gwt='git worktree'
ux_info "loaded"
EOF
chmod +x "$aliased"   # so the alias, not the missing mode bit, is what decides
eq "aliased: top-level alias marks the file sourced" \
  "$(row "$(sh "$here/sh_check.sh" "$aliased")" 2)" FAIL

# A shebang without the execute bit is a sourced fragment, not a script.
nonexec=$work/nonexec.sh
printf '#!/bin/sh\nux_info hi\n' > "$nonexec"   # deliberately not chmod +x
eq "nonexec: a shebang without the execute bit still needs a guard" \
  "$(row "$(sh "$here/sh_check.sh" "$nonexec")" 2)" FAIL

# A function merely named *helper* does not satisfy the help-flag check.
namebait=$work/namebait.sh
cat > "$namebait" <<'EOF'
#!/bin/sh
help_text_builder() { ux_info "..."; }
run() {
    case "$1" in
        -h|--help) ux_info "usage: run"; return 0 ;;
    esac
}
EOF
eq "namebait: a *help* substring is not a help function" \
  "$(row "$(sh "$here/sh_check.sh" "$namebait")" 6)" WARN

# Nor does a *help function nothing ever calls.
orphan=$work/orphan.sh
cat > "$orphan" <<'EOF'
#!/bin/sh
render_help() { ux_info "usage: run"; }
run() {
    case "$1" in
        -h|--help) ux_info "usage: run"; return 0 ;;
    esac
}
EOF
eq "orphan: an uncalled *help function is not delegation" \
  "$(row "$(sh "$here/sh_check.sh" "$orphan")" 6)" WARN

# `--help` written in prose is not flag handling.
prose=$work/prose.sh
cat > "$prose" <<'EOF'
#!/bin/sh
# run --help would be nice; nothing here handles it yet
run() {
    ux_info "$1"
}
EOF
eq "prose: --help in a comment is not flag handling" \
  "$(row "$(sh "$here/sh_check.sh" "$prose")" 6)" FAIL

# ...but a spaced-out equality test is.
spaced_flag=$work/spaced_flag.sh
cat > "$spaced_flag" <<'EOF'
#!/bin/sh
run_help() { ux_info "usage: run"; }
run() {
    if [ "$1" = "--help" ]; then
        run_help
        return 0
    fi
}
EOF
eq "spaced_flag: a --help equality test counts as flag handling" \
  "$(row "$(sh "$here/sh_check.sh" "$spaced_flag")" 6)" PASS

# ---------- Check 9/10: a help-table renderer is not a verdict (#104) ----------
rows=$work/rows.sh
cat > "$rows" <<'EOF'
#!/bin/sh
_rw_rows_status() {
    ux_table_row "syntax" "rw status" "Per-item diagnostic"
    ux_table_row "verdict" "dirty/clean" "+ Next action hint"
}
EOF
rw=$(sh "$here/sh_check.sh" "$rows")
eq "rows: ux_table_row-only *_status (no _help_ in name) is not a verdict (9)" "$(row "$rw" 9)" 'N/A'
eq "rows: ux_table_row-only *_status (no _help_ in name) is not a verdict (10)" "$(row "$rw" 10)" 'N/A'
hrow=$work/hrow.sh
printf '#!/bin/sh\n_hr_help_rows_status() { ux_success "key set"; }\n' > "$hrow"
eq "hrow: a *_help_* renderer without fixed lines is not a verdict" \
  "$(row "$(sh "$here/sh_check.sh" "$hrow")" 9)" 'N/A'
cat "$vpass" > "$work/vrows.sh"
printf '%s\n' '_vt_status_rows() { ux_table_row "a" "b"; }' >> "$work/vrows.sh"
printf '#!/bin/sh\n_cm_status() {\n    # no ux_table_row here, only this comment\n    echo ok\n}\n' > "$work/vcm.sh"
eq "vcm: ux_table_row in a comment does not hide a verdict" \
  "$(row "$(sh "$here/sh_check.sh" "$work/vcm.sh")" 9)" FAIL
eq "vrows: the real verdict still decides 9 beside a table renderer" \
  "$(row "$(sh "$here/sh_check.sh" "$work/vrows.sh")" 9)" PASS

# ---------- Check 6: a thin wrapper delegating "$@" (#104, dotfiles#2195) ----------
mkdir -p "$work/dotfiles/shell-common/tools/custom"
wtool=$work/dotfiles/shell-common/tools/custom/wtool.sh
printf '#!/bin/bash\ncase "$1" in help | -h | --help) echo usage ;; esac\n' > "$wtool"
wrap=$work/dotfiles/shell-common/functions/wtool.sh
cat > "$wrap" <<'EOF'
#!/bin/sh
wtool() {
    local _exe="${SHELL_COMMON:-${DOTFILES_ROOT:-$HOME/dotfiles}/shell-common}"/tools/custom/wtool.sh
    "$_exe" "$@"
}
EOF
w=$(sh "$here/sh_check.sh" "$wrap")
eq "wrap: \$_exe \"\$@\" credits the target's --help" "$(row "$w" 6)" PASS
eq "wrap: the note names the target" \
  "$(printf '%s\n' "$w" | awk -F'\t' '$1 == 6 { print $3 }')" "delegates --help to $wtool"
wlit=$work/dotfiles/shell-common/functions/wlit.sh
printf '#!/bin/sh\nwlit() { "${SHELL_COMMON}"/tools/custom/wtool.sh "$@"; }\n' > "$wlit"
eq "wlit: a one-line .../x.sh \"\$@\" credits the target's --help" \
  "$(row "$(sh "$here/sh_check.sh" "$wlit")" 6)" PASS
printf '#!/bin/bash\necho no help here\n' > "$wtool"
eq "wrap: a target without --help is FAIL" "$(row "$(sh "$here/sh_check.sh" "$wrap")" 6)" FAIL
wgone=$work/dotfiles/shell-common/functions/wgone.sh
printf '#!/bin/sh\nwgone() {\n    _exe="$HOME"/nowhere/wgone-missing.sh\n    "$_exe" "$@"\n}\n' > "$wgone"
eq "wgone: an unresolved target stays FAIL" "$(row "$(sh "$here/sh_check.sh" "$wgone")" 6)" FAIL
printf '#!/bin/bash\ncase "$1" in help | -h | --help) echo usage ;; esac\n' > "$wtool"
wcom=$work/dotfiles/shell-common/functions/wcom.sh
printf '#!/bin/sh\nwcom() {\n    _exe="${SHELL_COMMON}"/tools/custom/wtool.sh # the tool\n    "$_exe" "$@"\n}\n' > "$wcom"
eq "wcom: a trailing comment on the assignment still resolves" \
  "$(sh "$here/sh_check.sh" "$wcom" | awk -F'\t' '$1 == 6 { print $3 }')" \
  "delegates --help to $wtool"
# Quotes and spaces inside the default expansion do not reach the tail (PR #105, agy).
wsp=$work/dotfiles/shell-common/functions/wsp.sh
printf '#!/bin/sh\nwsp() {\n    local _exe="${FOO:-"$HOME/dir/a b"}"/tools/custom/wtool.sh\n    exec "$_exe" "$@"\n}\n' > "$wsp"
eq "wsp: a quoted, spaced default and an exec prefix still resolve" \
  "$(row "$(sh "$here/sh_check.sh" "$wsp")" 6)" PASS
# A binary target is never grepped as text, even with --help) in its bytes.
wbin=$work/dotfiles/shell-common/tools/custom/wbin.sh
printf '\177ELF\000\000 -h|--help) \000\n' > "$wbin"
printf '#!/bin/sh\nwb() { "${SHELL_COMMON}"/tools/custom/wbin.sh "$@"; }\n' > "$work/dotfiles/shell-common/functions/wb.sh"
eq "wbin: a binary target is not credited with --help" \
  "$(row "$(sh "$here/sh_check.sh" "$work/dotfiles/shell-common/functions/wb.sh")" 6)" FAIL
mkdir -p "$work/dotfiles/nowhere-abs"
printf '#!/bin/bash\ncase "$1" in -h | --help) echo usage ;; esac\n' > "$work/dotfiles/nowhere-abs/wtool.sh"
wabs=$work/dotfiles/shell-common/functions/wabs.sh
printf '#!/bin/sh\nwabs() { /nowhere-abs/wtool.sh "$@"; }\n' > "$wabs"
eq "wabs: a missing literal absolute target is not re-rooted under ancestors" \
  "$(row "$(sh "$here/sh_check.sh" "$wabs")" 6)" FAIL

# ---------- Check 6: env-prefixed and interpreter wrappers (#106) ----------
wenv=$work/dotfiles/shell-common/functions/wenv.sh
cat > "$wenv" <<'EOF2'
#!/bin/sh
wenv() {
    local _exe="${SHELL_COMMON}"/tools/custom/wtool.sh
    local _cd_file
    _cd_file=$(mktemp) || return 1
    WENV_CD_FILE="$_cd_file" "$_exe" "$@"
    cd "$(cat "$_cd_file")" || return 1
}
EOF2
eq "wenv: VAR=... \"\$_exe\" \"\$@\" is delegation (A-1)" \
  "$(sh "$here/sh_check.sh" "$wenv" | awk -F'\t' '$1 == 6 { print $2 " " $3 }')" "PASS delegates --help to $wtool"
nohelp=$work/dotfiles/shell-common/tools/custom/nohelp.sh
printf '#!/bin/bash\nread -r t u < <(free -h | awk "NR==2 {print \\$2}")\n' > "$nohelp"; chmod +x "$nohelp"
wbash=$work/dotfiles/shell-common/functions/wbash.sh
cat > "$wbash" <<'EOF2'
#!/bin/sh
wone() {
    local script="${SHELL_COMMON}/tools/custom/wtool.sh"
    [ -f "$script" ] || return 2
    bash "$script" "$@"
}
wtwo() {
    local script="${SHELL_COMMON}/tools/custom/nohelp.sh"
    [ -f "$script" ] || return 2
    sh "$script" "$@"
}
EOF2
eq "wbash: bash/sh \"\$var\" \"\$@\" judges every call by its nearest assignment (A-2)" \
  "$(sh "$here/sh_check.sh" "$wbash" | awk -F'\t' '$1 == 6 { print $2 " " $3 }')" \
  "FAIL delegates to $nohelp, which has no -h/--help handling"
eq "nohelp: '-h | awk' is a pipe, not a case pattern" \
  "$(row "$(sh "$here/sh_check.sh" "$nohelp")" 6)" FAIL

# ---------- Check 6: who is asked for --help (#106) ----------
fns=$work/dotfiles/shell-common/functions
printf '#!/bin/sh\n_priv_run() { echo "$1"; }\n_priv_sum() { echo "$@"; }\n' > "$fns/priv.sh"
eq "priv: only _private helpers -> N/A no public command (B)" \
  "$(sh "$here/sh_check.sh" "$fns/priv.sh" | awk -F'\t' '$1 == 6 { print $2 " " $3 }')" 'N/A no public command'
printf '#!/bin/sh\nzsh_switch() {\n    exec zsh -i\n}\n' > "$fns/noarg.sh"
eq "noarg: a public command reading no \$1/\$@/\$# -> N/A (C-a)" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/noarg.sh")" 6)" 'N/A'
printf '#!/bin/sh\nthing_help() {\n    ux_info "usage: thing $1"\n}\n' > "$fns/thing_help.sh"
eq "thelp: a *_help renderer is not asked for --help (C-b)" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/thing_help.sh")" 6)" 'N/A'
printf '#!/bin/sh\ninit_summary() {\n    local n="${1:-0}"\n    ux_success "$n"\n}\n' > "$fns/hook.sh"
eq "hook: an init hook taking an argument stays FAIL (auditor may override)" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/hook.sh")" 6)" FAIL
printf '#!/bin/sh\nshow_help() {\n    case "$1" in -h|--help) ux_info "usage"; return 0 ;; esac\n}\nx() { show_help; }\n' > "$fns/hhelp.sh"
eq "hhelp: help a file does handle still scores PASS, not N/A" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/hhelp.sh")" 6)" PASS
printf '#!/bin/sh\n_main() { echo hi; }\n_main\n' > "$work/exe.sh"; chmod +x "$work/exe.sh"
eq "exe: an executable script with only _helpers is still asked for --help" \
  "$(row "$(sh "$here/sh_check.sh" "$work/exe.sh")" 6)" FAIL
cat > "$fns/quoted.sh" <<'EOF2'
#!/bin/sh
ps_top() {
    ps aux | awk '{print $2}' | head -n "${#PATH}"
}
EOF2
eq "quoted: \$2 in an awk program and \${#var} are not argument reads -> N/A" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/quoted.sh")" 6)" 'N/A'
printf '#!/bin/sh\nopt_cmd() {\n    while getopts v o; do :; done\n}\nloop_cmd() {\n    for a; do :; done\n}\n' > "$fns/implicit.sh"
eq "implicit: getopts / for a; do read arguments -> FAIL, not N/A" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/implicit.sh")" 6)" FAIL
printf '#!/bin/sh\nfunction kw {\n    echo "$1"\n}\nif true; then\n    ind() { echo "$1"; }\nfi\n' > "$fns/unseen.sh"
eq "unseen: definitions FUNCS cannot parse are not N/A no public command" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/unseen.sh")" 6)" FAIL
printf '#!/bin/sh\nalias gs=_gs\n_gs() { git status "$@"; }\n' > "$fns/alias.sh"
eq "alias: an alias exposing a _private function is still asked" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/alias.sh")" 6)" FAIL

# ---------- PR #107 review: glob arms, subshell pipes, assignment order ----------
for arm in '*--help*)' '--help=*)' '-h*)'; do
  printf '#!/bin/sh\nglob_cmd() {\n    case "$1" in %s ux_info usage; return 0 ;; esac\n}\n' "$arm" > "$fns/glob.sh"
  eq "glob: '$arm' is flag handling" "$(row "$(sh "$here/sh_check.sh" "$fns/glob.sh")" 6)" WARN
done
printf '#!/bin/bash\nm=$(free -h | sort)\nn=$(du -h|tail)\n' > "$work/subp.sh"; chmod +x "$work/subp.sh"
eq "subp: '-h | word)' closing \$(...) is not flag handling" \
  "$(row "$(sh "$here/sh_check.sh" "$work/subp.sh")" 6)" FAIL
cat > "$fns/wlate.sh" <<'EOF2'
#!/bin/sh
wlate() {
    "$_wl_exe" "$@"
}
_wl_exe="${SHELL_COMMON}"/tools/custom/wtool.sh
EOF2
eq "wlate: a top-level assignment below the call still resolves" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/wlate.sh")" 6)" PASS
cat > "$fns/wmix.sh" <<'EOF2'
#!/bin/sh
wmix() {
    local _exe="${SHELL_COMMON}"/tools/custom/wtool.sh
    "$_exe" "$@"
}
wedit() {
    "$EDITOR" "$@"
}
EOF2
eq "wmix: an unresolvable call beside a resolved wrapper does not FAIL it" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/wmix.sh")" 6)" PASS
printf '#!/bin/sh\nsay_it() {\n    echo "don'"'"'t" "$1" '"'"'x'"'"'\n}\n' > "$fns/dq.sh"
eq "dq: an apostrophe inside double quotes does not hide \$1" \
  "$(row "$(sh "$here/sh_check.sh" "$fns/dq.sh")" 6)" FAIL

# ---------- Safety checks 11-14 (issue #108) ----------
sf=$work/safety
mkdir -p "$sf"

# The issue's own sample. The class comes from the execute bit, as everywhere.
scr "$sf/risky.sh" <<'EOF'
#!/bin/bash
# Usage: risky.sh <dir>
_show_help() { echo "usage"; }
case "$1" in -h|--help) _show_help; exit 0 ;; esac
target=$1
cd $target
tmp=/tmp/risky.$$
for f in `ls *.log`; do
    cat $f >> $tmp
done
rm -rf $target/*
EOF
eq "risky: 11 predictable path is FAIL" "$(safety "$sf/risky.sh" 11)" FAIL
eq "risky: 11 note names the path" "$(safety_note "$sf/risky.sh" 11)" 'predictable temp path /tmp/risky.$$'
eq "risky: 14 rm -rf with no flag is WARN" "$(safety "$sf/risky.sh" 14)" WARN
eq "risky: 12 and 13 do not apply" "$(safety "$sf/risky.sh" 12) $(safety "$sf/risky.sh" 13)" 'N/A N/A'
eq "risky: effective total drops N/A" "$(safety_score "$sf/risky.sh")" 0/2

# Row order, and the contract with and without judgments.
r=$(sh "$here/sh_check.sh" "$sf/risky.sh" PASS PASS)
eq "safety: four rows, score row, then the 10-point score" \
  "$(printf '%s\n' "$r" | tail -6 | cut -f1,2 | tr '\t\n' '  ')" \
  'safety 11 safety 12 safety 13 safety 14 safety-score 0/2 score 5/5 '
eq "safety: no judgments still prints every row" \
  "$(sh "$here/sh_check.sh" "$sf/risky.sh" | grep -c '^safety')" 5
eq "safety: never in the check column" \
  "$(printf '%s\n' "$r" | awk -F'\t' '$1 ~ /^1[1-4]$/' | grep -c . || true)" 0

# Empty file and all N/A.
: > "$sf/empty.sh"
eq "empty: 11-14 N/A" \
  "$(for i in 11 12 13 14; do safety "$sf/empty.sh" "$i"; done | tr '\n' ' ')" 'N/A N/A N/A N/A '
eq "empty: safety-score 0/0" "$(safety_score "$sf/empty.sh")" 0/0

# Comments, heredocs and strings are not code.
scr "$sf/prose.sh" <<'EOF'
#!/bin/sh
# never write to /tmp/foo or rm -rf /; sudo git push is fine in a comment
cat <<USAGE
tmp=/tmp/example
rm -rf "$HOME/x"
sudo git push origin main &
USAGE
cat <<-'INDENTED'
	x=/tmp/y > /tmp/z
	INDENTED
ux_info "rm -rf /tmp/foo is how you would do it, trap 'x' EXIT"
ux_info 'git push && gh pr create; sleep 9 &'
EOF
eq "prose: 11 N/A with /tmp only in comment, heredoc, string" "$(safety "$sf/prose.sh" 11)" 'N/A'
eq "prose: 14 N/A with rm -rf only in comment, heredoc, string" "$(safety "$sf/prose.sh" 14)" 'N/A'
eq "prose: 13 N/A with & only in heredoc, string" "$(safety "$sf/prose.sh" 13)" 'N/A'
scr "$sf/openhd.sh" <<'EOF'
#!/bin/sh
cat <<NEVER
rm -rf /
tmp=/tmp/x
EOF
eq "openhd: an unclosed heredoc runs to EOF, rows lean N/A" \
  "$(safety "$sf/openhd.sh" 11) $(safety "$sf/openhd.sh" 14)" 'N/A N/A'
scr "$sf/shift.sh" <<'EOF'
#!/bin/sh
x=$(( 1 << n ))
y=$(( a > b ))
if [ "${x#*/}" = "$#" ]; then rm -rf "$y"; fi
EOF
eq "shift: arithmetic << is no heredoc, \$# and \${x#} no comment" "$(safety "$sf/shift.sh" 14)" WARN
eq "shift: arithmetic > is no redirect" "$(safety "$sf/shift.sh" 12)" 'N/A'

# Check 11.
scr "$sf/tmp_ok.sh" <<'EOF'
#!/bin/sh
_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$_dir"' EXIT
EOF
eq "11: mktemp + rm in the EXIT trap is PASS" "$(safety "$sf/tmp_ok.sh" 11)" PASS
scr "$sf/tmp_fn.sh" <<'EOF'
#!/bin/bash
_cleanup() {
    _drop
}
_drop() { rm -f "$tmp"; }
main() {
    local tmp
    tmp="$(mktemp)"
    trap _cleanup EXIT INT TERM
}
main
EOF
eq "11: rm in a function the trap calls, transitively, is PASS" "$(safety "$sf/tmp_fn.sh" 11)" PASS
scr "$sf/tmp_dq.sh" <<'EOF'
#!/bin/bash
t=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf $t" EXIT
EOF
eq "11: a double-quoted trap body counts" "$(safety "$sf/tmp_dq.sh" 11)" PASS
scr "$sf/tmp_multi.sh" <<'EOF'
#!/bin/bash
t=$(mktemp)
trap '
    rm -f "$t"
' EXIT
EOF
eq "11: a multi-line trap body counts" "$(safety "$sf/tmp_multi.sh" 11)" PASS
scr "$sf/tmp_cont.sh" <<'EOF'
#!/bin/bash
t=$(mktemp)
trap 'rm -f "$t"' \
    EXIT
EOF
eq "11: signals on a continuation line count" "$(safety "$sf/tmp_cont.sh" 11)" PASS
scr "$sf/tmp_warn.sh" <<'EOF'
#!/bin/sh
t=$(mktemp)
work "$t"
rm -f "$t"
EOF
eq "11: rm without a trap is WARN" "$(safety "$sf/tmp_warn.sh" 11)" WARN
scr "$sf/tmp_leak.sh" <<'EOF'
#!/bin/sh
t=$(mktemp)
work "$t"
rm -f other
EOF
eq "11: a mktemp result nothing removes is FAIL" "$(safety "$sf/tmp_leak.sh" 11)" FAIL
eq "11: the note names the variable" "$(safety_note "$sf/tmp_leak.sh" 11)" 'mktemp result $t is never removed'
scr "$sf/tmp_two.sh" <<'EOF'
#!/bin/sh
a=$(mktemp)
b=$(mktemp)
trap 'rm -f "$b"' EXIT
EOF
eq "11: the trap must reach every mktemp result" "$(safety "$sf/tmp_two.sh" 11)" FAIL
scr "$sf/tmp_alias.sh" <<'EOF'
#!/bin/bash
a=$(mktemp); b=$(mktemp -d)
keep=("$a" "$b")
trap 'for f in "${keep[@]}"; do rm -rf "$f"; done' EXIT
EOF
eq "11: removal through an array and a loop variable counts" "$(safety "$sf/tmp_alias.sh" 11)" PASS
scr "$sf/tmp_in.sh" <<'EOF'
#!/bin/sh
d=$(mktemp -d)
f=$(mktemp "$d/x.XXXXXX")
trap 'rm -rf "$d"' EXIT
EOF
eq "11: a mktemp inside a removed mktemp directory is covered" "$(safety "$sf/tmp_in.sh" 11)" PASS
scr "$sf/tmp_tpl.sh" <<'EOF'
#!/bin/sh
t=$(mktemp /tmp/app.XXXXXX)
trap 'rm -f "$t"' EXIT
u="/tmp/$(id -u).XXXXXX"
EOF
eq "11: a /tmp mktemp template is not a fixed path" "$(safety "$sf/tmp_tpl.sh" 11)" PASS
scr "$sf/tmp_ret.sh" <<'EOF'
#!/bin/sh
_mk_temp() {
    local _path
    _path=$(mktemp) || return 1
    printf '%s\n' "$_path"
}
EOF
eq "11: a helper printing its mktemp path hands it to the caller" "$(safety "$sf/tmp_ret.sh" 11)" WARN
scr "$sf/tmp_redir.sh" <<'EOF'
#!/bin/sh
date > "/tmp/stamp"
EOF
eq "11: a redirect to a fixed /tmp path is FAIL" "$(safety "$sf/tmp_redir.sh" 11)" FAIL
frag "$sf/frag_ok.sh" <<'EOF'
#!/bin/sh
case $- in *i*) ;; *) return 0 ;; esac
show() {
    _t=$(mktemp)
    cat "$_t"
    rm -f "$_t"
}
EOF
eq "11: sourced, mktemp on an rm line, no EXIT trap is PASS" "$(safety "$sf/frag_ok.sh" 11)" PASS
frag "$sf/frag_trap.sh" <<'EOF'
#!/bin/sh
case $- in *i*) ;; *) return 0 ;; esac
show() {
    _t=$(mktemp)
    trap 'rm -f "$_t"' EXIT
}
EOF
eq "11: sourced EXIT trap overrides the caller, WARN" "$(safety "$sf/frag_trap.sh" 11)" WARN

# Check 12.
scr "$sf/at_ok.sh" <<'EOF'
#!/bin/sh
tmp=$(mktemp "$(dirname "$1")/.x.XXXXXX") || exit 1
trap 'rm -f "$tmp"' EXIT
printf 'x' > "$tmp"
mv "$tmp" "$1"
EOF
eq "12: same-directory mktemp + mv is PASS" "$(safety "$sf/at_ok.sh" 12)" PASS
scr "$sf/at_pct.sh" <<'EOF'
#!/bin/sh
target=$1
tmp=$(mktemp "${target%/*}/.x.XXXXXX")
mv -f "$tmp" "$target"
EOF
eq "12: \${x%/*} in the template is PASS" "$(safety "$sf/at_pct.sh" 12)" PASS
scr "$sf/at_var.sh" <<'EOF'
#!/bin/sh
dir=$(dirname "$1")
tmp=$(mktemp "$dir/.x.XXXXXX")
mv "$tmp" "$1"
EOF
eq "12: a dirname variable in the template is PASS" "$(safety "$sf/at_var.sh" 12)" PASS
scr "$sf/at_pre.sh" <<'EOF'
#!/bin/sh
out=$1
tmp=$(mktemp "$out.XXXXXX")
mv "$tmp" "$out"
EOF
eq "12: a template built on the target is PASS" "$(safety "$sf/at_pre.sh" 12)" PASS
scr "$sf/at_def.sh" <<'EOF'
#!/bin/sh
tmp=$(mktemp)
printf 'x' > "$tmp"
mv "$tmp" "$1"
EOF
eq "12: default template + mv is WARN" "$(safety "$sf/at_def.sh" 12)" WARN
scr "$sf/at_dir.sh" <<'EOF'
#!/bin/sh
printf 'x' > "$1"
EOF
eq "12: a direct > is WARN" "$(safety "$sf/at_dir.sh" 12)" WARN
scr "$sf/at_none.sh" <<'EOF'
#!/bin/sh
ls >/dev/null 2>&1
ls > "/dev/null"
ls >&2
ls >> "$1"
t=$(mktemp); trap 'rm -f "$t"' EXIT
ls > "$t"
ls > "$t.sorted"
[[ "$a" > "$b" ]] && ls
(( a > b )) && ls
EOF
eq "12: >>, /dev/*, fds, temp variables and comparisons are N/A" "$(safety "$sf/at_none.sh" 12)" 'N/A'
scr "$sf/at_lit.sh" <<'EOF'
#!/bin/sh
ls > "$1.tmp"
mv "$1.tmp" "$1"
EOF
eq "12: a redirect target later moved away is a temp file" "$(safety "$sf/at_lit.sh" 12)" 'N/A'

# Check 13.
printf '#!/bin/sh\nt=x\ntrap "echo $t" EXIT\n' > "$sf/sig_sh.sh"; chmod +x "$sf/sig_sh.sh"
printf '#!/bin/bash\nt=x\ntrap "echo $t" EXIT\n' > "$sf/sig_bash.sh"; chmod +x "$sf/sig_bash.sh"
eq "13: #!/bin/sh EXIT trap alone is WARN" "$(safety "$sf/sig_sh.sh" 13)" WARN
eq "13: the same code under #!/bin/bash is N/A" "$(safety "$sf/sig_bash.sh" 13)" 'N/A'
scr "$sf/sig_nohup.sh" <<'EOF'
#!/bin/sh
nohup cmd >/dev/null 2>&1 &
setsid cmd &
cmd & disown
cmd &
disown
EOF
eq "13: nohup, setsid and disown are N/A" "$(safety "$sf/sig_nohup.sh" 13)" 'N/A'
scr "$sf/sig_bg.sh" <<'EOF'
#!/bin/sh
cmd &
wait
EOF
eq "13: a plain background job with no trap is FAIL" "$(safety "$sf/sig_bg.sh" 13)" FAIL
scr "$sf/sig_fg.sh" <<'EOF'
#!/bin/sh
a && b
c &> /dev/null
d 2>&1 | e
f "x & y"
EOF
eq "13: &&, &>, >& and a quoted & are no background job" "$(safety "$sf/sig_fg.sh" 13)" 'N/A'
scr "$sf/sig_one.sh" <<'EOF'
#!/bin/sh
cmd &
trap 'kill $!' INT
EOF
eq "13: only one of INT/TERM is WARN" "$(safety "$sf/sig_one.sh" 13)" WARN
scr "$sf/sig_ok.sh" <<'EOF'
#!/bin/sh
_stop() { kill "$_pid"; }
cmd & _pid=$!
trap _stop SIGINT SIGTERM
wait
EOF
eq "13: both signals and kill in the cleanup path is PASS" "$(safety "$sf/sig_ok.sh" 13)" PASS
scr "$sf/sig_chain.sh" <<'EOF'
#!/bin/sh
cmd & _pid=$!
trap 'kill "$_pid"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
EOF
eq "13: the EXIT trap is part of the cleanup path" "$(safety "$sf/sig_chain.sh" 13)" PASS
scr "$sf/sig_nokill.sh" <<'EOF'
#!/bin/sh
cmd &
trap 'echo bye' INT TERM
EOF
eq "13: trapped but neither kill nor wait is WARN" "$(safety "$sf/sig_nokill.sh" 13)" WARN
scr "$sf/sig_shok.sh" <<'EOF'
#!/bin/sh
t=$(mktemp)
trap 'rm -f "$t"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
EOF
eq "13: #!/bin/sh with EXIT, INT and TERM is PASS" "$(safety "$sf/sig_shok.sh" 13)" PASS
scr "$sf/sig_rst.sh" <<'EOF'
#!/bin/sh
trap - EXIT
trap '' INT
EOF
eq "13: a trap reset or ignore is no cleanup" "$(safety "$sf/sig_rst.sh" 13)" 'N/A'

# Check 14.
scr "$sf/dry_apply.sh" <<'EOF'
#!/bin/sh
apply=0
case "${1:-}" in
    --apply) apply=1 ;;
esac
if [ "$apply" = 1 ]; then
    rm -rf "$HOME/x"
fi
EOF
eq "14: --apply read in a condition is PASS" "$(safety "$sf/dry_apply.sh" 14)" PASS
scr "$sf/dry_parse.sh" <<'EOF'
#!/bin/sh
apply=0
case "${1:-}" in
    --apply) apply=1 ;;
esac
rm -rf "$HOME/x"
EOF
eq "14: --apply parsed but never read is WARN" "$(safety "$sf/dry_parse.sh" 14)" WARN
scr "$sf/dry_n.sh" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=1
            ;;
    esac
    shift
done
if [ -n "${DRY_RUN:-}" ]; then echo plan; else git push; fi
EOF
eq "14: -n setting DRY_RUN, read in a condition, is PASS" "$(safety "$sf/dry_n.sh" 14)" PASS
scr "$sf/dry_opts.sh" <<'EOF'
#!/bin/sh
while getopts nv o; do
    case $o in
        n) noop=1 ;;
    esac
done
[ -n "$noop" ] && exit 0
git reset --hard HEAD
EOF
eq "14: a getopts n arm is option position" "$(safety "$sf/dry_opts.sh" 14)" PASS
scr "$sf/dry_test.sh" <<'EOF'
#!/bin/sh
if [ "$1" != "--apply" ]; then
    echo would delete
    exit 0
fi
sudo rm -rf /opt/x
EOF
eq "14: an option test gating the code directly is PASS" "$(safety "$sf/dry_test.sh" 14)" PASS
scr "$sf/dry_arg.sh" <<'EOF'
#!/bin/sh
_run() {
    local dry_run="$1"
    if [ "$dry_run" = 1 ]; then return 0; fi
    rm -rf "$HOME/x"
}
case "$1" in
    --dry-run) _run 1 ;;
    *) _run 0 ;;
esac
EOF
eq "14: a flag handed to a function by value is PASS" "$(safety "$sf/dry_arg.sh" 14)" PASS
scr "$sf/dry_opt.sh" <<'EOF'
#!/bin/sh
echo "pass -n) or --dry-run) or --apply) for a plan"
sort -n "$1" | tail -1
x=$(sort -n | head)
[ -n "$x" ] && git push
EOF
eq "14: -n in a string or on another command is no flag" "$(safety_note "$sf/dry_opt.sh" 14)" \
  '1 mutating command(s), first git push, no --dry-run/--apply'
scr "$sf/dry_tmp.sh" <<'EOF'
#!/bin/sh
t=$(mktemp); d=$(mktemp -d)
copy="$d/x"
trap 'rm -rf "$d"' EXIT
rm -f "$t"
rm -f "$d/one" "$copy"
EOF
eq "14: rm of mktemp variables only is N/A" "$(safety "$sf/dry_tmp.sh" 14)" 'N/A'
scr "$sf/dry_mix.sh" <<'EOF'
#!/bin/sh
t=$(mktemp)
trap 'rm -f "$t"' EXIT
rm -f "$t" "$1"
EOF
eq "14: rm of a mktemp variable and a real path is WARN" "$(safety "$sf/dry_mix.sh" 14)" WARN
scr "$sf/dry_gh.sh" <<'EOF'
#!/bin/sh
out=$(GH_HOST=x gh pr create --fill)
gh pr view 1
rm "$1"
EOF
eq "14: gh ... create under an env prefix is a mutating call" "$(safety_note "$sf/dry_gh.sh" 14)" \
  '1 mutating command(s), first gh write, no --dry-run/--apply'
scr "$sf/dry_ro.sh" <<'EOF'
#!/bin/sh
gh pr view 1
git status
rm "$1"
EOF
eq "14: reads and a plain rm are N/A" "$(safety "$sf/dry_ro.sh" 14)" 'N/A'
frag "$sf/dry_priv.sh" <<'EOF'
#!/bin/sh
case $- in *i*) ;; *) return 0 ;; esac
_private() { rm -rf "$1"; }
rm -rf "$HOME/top-level"
EOF
eq "14: sourced, private helper and top level are out of scope" "$(safety "$sf/dry_priv.sh" 14)" 'N/A'
frag "$sf/dry_pub.sh" <<'EOF'
#!/bin/sh
case $- in *i*) ;; *) return 0 ;; esac
wipe() { rm -rf "$1"; }
EOF
eq "14: sourced, public function is WARN" "$(safety "$sf/dry_pub.sh" 14)" WARN

# The syntax-broken file still reports; nothing edits the audited file.
scr "$sf/broken.sh" <<'EOF'
#!/bin/sh
if [ "$a ; then
echo 'unterminated
EOF
eq "broken: a syntax error still yields four rows" "$(sh "$here/sh_check.sh" "$sf/broken.sh" | grep -c '^safety	')" 4
before=$(cksum < "$sf/risky.sh")
sh "$here/sh_check.sh" "$sf/risky.sh" PASS PASS >/dev/null
eq "read-only: the audited file is unchanged" "$(cksum < "$sf/risky.sh")" "$before"

# Next Actions snippets stay POSIX.
refs=$here/../references
safety_docs=$(awk '/^## Safety Checks/ { on = 1; print; next } /^## / { on = 0 } on' "$refs/checks.md")
eq "docs: checks.md has a Safety Checks section" "$(printf '%s\n' "$safety_docs" | grep -c '^### Check 1[1-4] ')" 4
eq "docs: Safety snippets and Next Actions avoid [[, declare, mapfile" \
  "$({ printf '%s\n' "$safety_docs"; awk '/^### Next Actions/,/^```$/' "$refs/report-template.md"; } | grep -cE '\[\[|declare|mapfile' || true)" 0

# ---------- usage errors ----------
if sh "$here/sh_check.sh" >/dev/null 2>&1; then
  no "usage: no argument" "exited 0, expected 2"
else
  ok "usage: no argument"
fi
if sh "$here/sh_check.sh" "$plain" PASS >/dev/null 2>&1; then
  no "usage: partial judgments" "exited 0, expected 2"
else
  ok "usage: partial judgments"
fi
if sh "$here/sh_check.sh" "$plain" PASS MAYBE >/dev/null 2>&1; then
  no "usage: bad judgment word" "exited 0, expected 2"
else
  ok "usage: bad judgment word"
fi
if sh "$here/sh_check.sh" "$plain" PASS PASS PASS PASS >/dev/null 2>&1; then
  no "usage: retired four-judgment form" "exited 0, expected 2"
else
  ok "usage: retired four-judgment form"
fi
if sh "$here/sh_check.sh" "$work/nope.sh" >/dev/null 2>&1; then
  no "usage: unreadable file" "exited 0, expected 2"
else
  ok "usage: unreadable file"
fi

[ "$fails" -eq 0 ] || { printf '\n%s check(s) failed\n' "$fails" >&2; exit 1; }
printf '\nall checks passed\n'
