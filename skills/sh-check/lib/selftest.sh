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
eq "vpass: 9/10 rows are deterministic" "$(sh "$here/sh_check.sh" "$vpass" | tail -2)" \
  "$(printf '%s\n' "$v" | tail -2)"
eq "vskill: a /plugin:skill NEXT is a command" "$(row "$(sh "$here/sh_check.sh" "$vskill")" 10)" PASS
eq "vfam: a gh-flow family NEXT is a command (issue #41)" "$(row "$(sh "$here/sh_check.sh" "$vfam")" 10)" PASS
eq "vlook: a lookalike prefix is still WARN" "$(row "$(sh "$here/sh_check.sh" "$vlook")" 10)" WARN
eq "vcd: cd X && <command> is a command (issue #47)" "$(row "$(sh "$here/sh_check.sh" "$vcd")" 10)" PASS
eq "vcdp: cd X && <prose> is still WARN" "$(row "$(sh "$here/sh_check.sh" "$vcdp")" 10)" WARN
eq "vcdb: cd X && <nothing> is still WARN" "$(row "$(sh "$here/sh_check.sh" "$vcdb")" 10)" WARN
eq "vthen: review ..., then <command> is still WARN" "$(row "$(sh "$here/sh_check.sh" "$vthen")" 10)" WARN
eq "vprose: prose NEXT is WARN, not FAIL" "$(row "$(sh "$here/sh_check.sh" "$vprose")" 10)" WARN
eq "vblank: blank NEXT is WARN" "$(row "$(sh "$here/sh_check.sh" "$vblank")" 10)" WARN

# ---------- per-verdict-function table (issue #39) ----------
vt=$(sh "$here/sh_check.sh" "$vpass" PASS PASS)
eq "vpass: fn row counts vocab and NEXT" "$(fnrows "$vt")" '_vt_compute_status 3 3/3 PASS'
eq "vpass: fn table sits right before the score row" \
  "$(printf '%s\n' "$vt" | tail -2 | cut -f1 | tr '\n' ' ')" 'fn score '
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
