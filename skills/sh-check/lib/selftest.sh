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
g=$(sh "$here/sh_check.sh" "$good" PASS PASS PASS PASS)
eq "good: 1 shebang"      "$(row "$g" 1)" PASS
eq "good: 2 guard"        "$(row "$g" 2)" PASS
eq "good: 4 naming"       "$(row "$g" 4)" PASS
eq "good: 5 zsh guard"    "$(row "$g" 5)" PASS
eq "good: 6 help flag"    "$(row "$g" 6)" PASS
eq "good: 7 ux lib"       "$(row "$g" 7)" PASS
eq "good: verdict"        "$(verdict "$g")" EXCELLENT

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
b=$(sh "$here/sh_check.sh" "$bad" FAIL FAIL FAIL FAIL)
eq "bad: 1 bash shebang in shell-common" "$(row "$b" 1)" FAIL
eq "bad: 2 no interactive guard"         "$(row "$b" 2)" FAIL
eq "bad: 4 camelCase"                    "$(row "$b" 4)" FAIL
eq "bad: 5 no emulate guard"             "$(row "$b" 5)" FAIL
eq "bad: 6 no help flag"                 "$(row "$b" 6)" FAIL
eq "bad: 7 raw echo only"                "$(row "$b" 7)" FAIL
eq "bad: verdict"                        "$(verdict "$b")" POOR

# ---------- N/A rows leave the denominator ----------
plain=$work/plain.sh
printf '#!/bin/sh\nexit 0\n' > "$plain"
chmod +x "$plain"   # checks.md Check 2: N/A needs the execute bit, not just #!
p=$(sh "$here/sh_check.sh" "$plain" 'N/A' 'N/A' 'N/A' 'N/A')
eq "plain: 4 no functions" "$(row "$p" 4)" 'N/A'
eq "plain: score drops N/A rows" \
  "$(printf '%s\n' "$p" | awk -F'\t' '$1 == "score" { print $2 }')" 1/2

# ---------- the verdict boundaries ----------
# mid.sh scores 4 mechanical PASS + 2 N/A, so the judgments move it across
# every band of the report-template.md table.
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
eq "mid: 8/8 is EXCELLENT" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" PASS PASS PASS PASS)")" EXCELLENT
eq "mid: 7/8 no FAIL is GOOD" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" PASS PASS PASS WARN)")" GOOD
eq "mid: 6/8 no FAIL is NEEDS WORK" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" WARN PASS PASS WARN)")" 'NEEDS WORK'
eq "mid: 5/8 with one FAIL is NEEDS WORK" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" FAIL WARN WARN PASS)")" 'NEEDS WORK'
eq "mid: 4/8 with two FAILs is POOR" \
  "$(verdict "$(sh "$here/sh_check.sh" "$mid" FAIL FAIL WARN WARN)")" POOR

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
if sh "$here/sh_check.sh" "$plain" PASS PASS PASS MAYBE >/dev/null 2>&1; then
  no "usage: bad judgment word" "exited 0, expected 2"
else
  ok "usage: bad judgment word"
fi
if sh "$here/sh_check.sh" "$work/nope.sh" >/dev/null 2>&1; then
  no "usage: unreadable file" "exited 0, expected 2"
else
  ok "usage: unreadable file"
fi

[ "$fails" -eq 0 ] || { printf '\n%s check(s) failed\n' "$fails" >&2; exit 1; }
printf '\nall checks passed\n'
