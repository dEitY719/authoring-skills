#!/bin/sh
# discover-refs.sh -- grep one command family's definitions and every
# reference-point category listed in references/discovery.md.
#
# Usage: discover-refs.sh <family-token> [dotfiles-root]
#   dotfiles-root defaults to $DOTFILES_ROOT, else $HOME/dotfiles.
#
# stdout: one row per hit -- category<TAB>file<TAB>line<TAB>text
#         file is relative to dotfiles-root. Categories:
#         definition, inline-help, installer, help-registry, help-adapter,
#         help-test, bats
# exit:   0 hits found | 1 no hits | 2 bad usage or missing root
#
# Read-only. Applying the rename is a separate /gh-flow:issue run.

set -eu

family=${1:-}
root=${2:-${DOTFILES_ROOT:-$HOME/dotfiles}}

case $family in
  -h|--help|help)
    echo "usage: discover-refs.sh <family-token> [dotfiles-root]"
    exit 0
    ;;
  '')
    echo "discover-refs: missing <family-token>" >&2
    exit 2
    ;;
esac

# The token goes straight into an ERE, so reject anything that could act as a
# metacharacter rather than silently matching the wrong thing.
case $family in
  *[!A-Za-z0-9_-]*)
    echo "discover-refs: <family-token> must match [A-Za-z0-9_-]+, got '$family'" >&2
    exit 2
    ;;
esac

[ -d "$root" ] || { echo "discover-refs: not a directory: $root" >&2; exit 2; }
cd "$root" || exit 2

# `_` is treated as a boundary so `_agy_run` and `agy-help` both hit while
# `shaggy` does not.
re="(^|[^A-Za-z0-9])$family([^A-Za-z0-9]|\$)"
# Only the inline-help category narrows further; every other category is
# already scoped by its path glob.
filter=''
found=0

# scan <category> <grep args...> -- extra args go BEFORE the path operands,
# which are always relative to `$root` (we chdir'd there), so no absolute
# prefix has to be stripped back off with a regex.
scan() {
  category=$1
  shift
  out=$(grep -rnE "$@" 2>/dev/null |
    sed -E "s|^\./||; s|^([^:]*):([0-9]+):|$category\t\1\t\2\t|" || true)
  # The filter applies to the matched text only -- a path such as
  # `agy_helpers.sh` must not pass the inline-help filter on its name alone.
  if [ -n "$filter" ]; then
    out=$(printf '%s\n' "$out" | awk -F'\t' -v f="$filter" '$4 ~ f' || true)
  fi
  [ -n "$out" ] || return 0
  printf '%s\n' "$out"
  found=1
}

# 1. Definitions -- alias/function declaration sites.
for d in shell-common/tools/integrations shell-common/functions; do
  if [ -d "$d" ]; then scan definition "$re" "$d"; fi
done

# 2. Reference points -- every category in discovery.md section 2.
filter='(#[[:space:]]*DOC:|[Hh]elp|HELP|[Uu]sage|USAGE)'
scan inline-help --include='*.sh' --include='*.zsh' --include='*.bash' "$re" .
filter=''
scan installer     --include='install_*.sh'                "$re" .
scan help-registry --include='my_help.sh'                  "$re" .
scan help-adapter  --include='zz_help_standard_adapter.sh' "$re" .
scan help-test     --include='test_help_*.py'              "$re" .
if [ -d tests/bats ]; then scan bats "$re" tests/bats; fi

[ "$found" -eq 1 ] || exit 1
