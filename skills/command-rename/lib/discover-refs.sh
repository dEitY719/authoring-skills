#!/bin/sh
# discover-refs.sh -- grep one command family's definitions and every
# reference-point category listed in references/discovery.md.
#
# Usage: discover-refs.sh <family-token> [dotfiles-root]
#   dotfiles-root defaults to $DOTFILES_ROOT, else $HOME/dotfiles.
#
# This sweep is dotfiles-scoped BY DESIGN: the category paths below
# (shell-common/, my_help.sh, zz_help_standard_adapter.sh, tests/bats)
# exist only in the dEitY719/dotfiles checkout. The caller's TARGET_REPO
# (SKILL.md Step 1) is an owner/repo slug naming where the *issue* gets
# filed -- it is not a filesystem path and is never a root for this sweep.
# To scan a checkout somewhere else, pass it as the second argument.
#
# Requires a grep with -r and --include (GNU/BSD extensions, not POSIX).
# On a grep without them this aborts (exit 3) rather than reporting "no hits".
#
# stdout: one row per hit -- category<TAB>file<TAB>line<TAB>text
#         file is relative to dotfiles-root. Categories:
#         definition, inline-help, reference, installer, help-registry,
#         help-adapter, help-test, bats
# exit:   0 hits found | 1 no hits | 2 bad usage or missing root
#         3 grep itself failed -- its stderr is reproduced; a category is
#           never silently dropped
#
# Read-only. Applying the rename is a separate /gh-flow:issue run.

set -eu

family=${1:-}
root=${2:-${DOTFILES_ROOT:-$HOME/dotfiles}}

case $family in
  -h|--help)
    echo "usage: discover-refs.sh <family-token> [dotfiles-root]"
    exit 0
    ;;
  # The token goes straight into an ERE, so reject anything that could act as a
  # metacharacter rather than silently matching the wrong thing. `help` is a
  # legitimate family token in a repo that ships `my_help.sh`, so it is not
  # accepted as a synonym for `--help`.
  '' | *[!A-Za-z0-9_-]*)
    echo "discover-refs: <family-token> must match [A-Za-z0-9_-]+, got '$family'" >&2
    exit 2
    ;;
esac

cd "$root" 2>/dev/null || { echo "discover-refs: cannot use root: $root" >&2; exit 2; }

# `_` sits inside the boundary class DELIBERATELY: it is what makes `_agy_run`
# -- a real definition site -- and `agy-help` hit, while `shaggy` does not.
# The accepted cost is that an unrelated `unrelated_agy_bar` hits too. That is
# a known false positive, not a bug: this is a read-only discovery tool whose
# rows a human reads and filters, and missing a real reference point is the
# expensive failure while an extra row costs one glance. Narrowing `_` out of
# the class would drop `_agy_run` and break the "ALL reference points"
# guarantee (references/discovery.md -> "Deliberate over-reporting").
re="(^|[^A-Za-z0-9])$family([^A-Za-z0-9]|\$)"
# A literal tab: `\t` in a sed replacement is a GNU extension and emits a bare
# `t` on BSD/macOS, which would silently break the TSV contract.
TAB=$(printf '\t')

err=$(mktemp)
trap 'rm -f "$err"' EXIT

# scan <category> <grep args...> -- extra args go BEFORE the path operands,
# which are always relative to `$root` (we chdir'd there), so no absolute
# prefix has to be stripped back off with a regex.
#
# grep's three outcomes are kept apart instead of being flattened by a blanket
# `2>/dev/null`: 0 = hits, 1 = no match (a legitimately empty category),
# >=2 = grep itself failed -- an unsupported option, an unreadable tree. Only
# the last is fatal, and it must be fatal: swallowing it turns "this grep
# cannot scope by path" into a zero-row category and a bogus "no hits" verdict.
scan() {
  category=$1
  shift
  rc=0
  hits=$(grep -rnE "$@" 2>"$err") || rc=$?
  if [ "$rc" -ge 2 ]; then
    echo "discover-refs: grep failed (exit $rc) scanning category '$category'" >&2
    sed 's/^/discover-refs: grep: /' "$err" >&2
    exit 3
  fi
  [ -n "$hits" ] || return 0
  # Squeeze tabs out of the matched text BEFORE building the row: a tab-indented
  # source line would otherwise push the row past 4 fields, breaking the TSV
  # contract and hiding the rest of the text from the classifier's $4 test.
  printf '%s\n' "$hits" |
    tr '\t' ' ' |
    sed -E "s|^\./||; s|^([^:]*):([0-9]+):|$category$TAB\1$TAB\2$TAB|"
}

rc=0
all=$(
  # 1. Definitions -- alias/function declaration sites.
  for d in shell-common/tools/integrations shell-common/functions; do
    if [ -d "$d" ]; then scan definition "$re" "$d"; fi
  done

  # 2. Reference points -- every category in discovery.md section 2.
  # The shell sweep is UNFILTERED: every *.sh/*.zsh/*.bash line naming the
  # family is emitted, so an ordinary command description is never dropped on
  # the floor. The DOC/help/usage test only CLASSIFIES -- a matching line is
  # `inline-help`, everything else stays the generic `reference`. Testing
  # field 4 rather than the whole row keeps a path such as `agy_helpers.sh`
  # from being called help text on the strength of its name alone.
  # Captured rather than piped straight into awk: a pipeline would swallow
  # scan's `exit 3` and report awk's status instead.
  refs=$(scan reference --include='*.sh' --include='*.zsh' --include='*.bash' "$re" .) || exit $?
  [ -z "$refs" ] || printf '%s\n' "$refs" |
    awk -F"$TAB" -v OFS="$TAB" \
        '$4 ~ /(#[[:space:]]*DOC:|[Hh]elp|HELP|[Uu]sage|USAGE)/ { $1 = "inline-help" } 1'

  scan installer     --include='install_*.sh'                "$re" .
  scan help-registry --include='my_help.sh'                  "$re" .
  scan help-adapter  --include='zz_help_standard_adapter.sh' "$re" .
  scan help-test     --include='test_help_*.py'              "$re" .
  if [ -d tests/bats ]; then scan bats "$re" tests/bats; fi
) || rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

[ -n "$all" ] || exit 1
printf '%s\n' "$all"
