#!/bin/sh
# scan-ux.sh -- the mechanical half of authoring:ux-guidelines Mode B.
#
# Mode B's discover-and-scan loop is a grep, not a judgment: the three
# patterns below are decidable from the text alone. This helper reports them
# so the model spends its turn on what only it can do -- deciding which hits
# are genuine user-facing output, writing the suggested fix, and grouping the
# report.
#
# Usage: scan-ux.sh [path ...]
#   Each path may be a *.sh file or a directory to walk. With no argument the
#   scope is $SHELL_COMMON, default $HOME/dotfiles/shell-common -- the
#   dEitY719/dotfiles checkout every `shell-common/...` path in this skill
#   refers to. Outside that checkout there is nothing to scan, which is why
#   the scope is an argument rather than a hardcoded glob.
#
# stdout: file<TAB>line<TAB>pattern<TAB>severity, one row per hit:
#   heredoc-help  high    a `cat <<EOF`-style help block
#   ansi-color    high    a hardcoded ANSI escape or COLOR_* variable
#   raw-status    medium  a bare echo of a status word (Done/Error/...)
#
# exit: 0 scan ran (with or without hits) | 2 bad usage or no readable path
#
# Read-only: never edits a scanned file. Severity model and the exclusions
# the model still has to apply: references/bulk-review-workflow.md.

set -eu

die() {
  printf '%s\n' "$1" >&2
  exit 2
}

if [ $# -eq 0 ]; then
  set -- "${SHELL_COMMON:-$HOME/dotfiles/shell-common}"
fi

# Collect the scan set first so an unreadable scope fails before any output.
files=$(
  for target in "$@"; do
    if [ -f "$target" ]; then
      printf '%s\n' "$target"
    elif [ -d "$target" ]; then
      find "$target" -type f -name '*.sh'
    else
      printf 'no such file or directory: %s\n' "$target" >&2
      exit 2
    fi
  done
)
[ -n "$files" ] || die "no *.sh file found in: $*"

# One awk pass per file rather than three greps: the same line can only be
# reported once per pattern, and the ordering stays file-then-line.
printf '%s\n' "$files" | while IFS= read -r f; do
  [ -r "$f" ] || continue
  awk -v file="$f" '
    # A comment is documentation, not output. Skipping them here is what keeps
    # a file that *describes* these patterns from reporting itself.
    /^[[:space:]]*#/ { next }
    # A here-doc opener carrying help text. `<<` plus an all-caps word is the
    # shape every hit in this repo family takes.
    /<<-?[[:space:]]*'"'"'?[A-Z]+'"'"'?/ {
      print file "\t" NR "\theredoc-help\thigh"
      next
    }
    # A hardcoded escape sequence, or one of the raw COLOR_* variables the
    # ux_* wrappers exist to replace.
    /\\033\[|\\e\[|\\x1[bB]\[|\$\{?COLOR_/ {
      print file "\t" NR "\tansi-color\thigh"
      next
    }
    # A status word printed as plain text where a semantic ux_* call belongs.
    /(echo|printf)[^|]*"(Done|OK|Error|Failed|Failure|Success|Warning|Warn)/ {
      print file "\t" NR "\traw-status\tmedium"
    }
  ' "$f"
done
