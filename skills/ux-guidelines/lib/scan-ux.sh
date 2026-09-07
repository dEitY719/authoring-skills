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
# exit: 0 scan ran and every file in scope was read | 1 at least one file in
#       scope could not be read (named on stderr) | 2 bad usage or no such path
#
# Exit 1 exists because Mode B promises a complete audit: a file skipped for
# permissions must not read as a clean one (codex PR #19 BLOCKER).
#
# Read-only: never edits a scanned file. Severity model and the exclusions
# the model still has to apply: references/bulk-review-workflow.md.
#
# ponytail: the scan set is passed to the loop one path per line, so a path
# containing a NEWLINE would be split. Spaces are safe (`IFS= read -r`, and
# lib/selftest.sh asserts it); a newline is the ceiling. Upgrade path if that
# ever matters: `find -print0` and a reader that splits on NUL, which POSIX sh
# `read` cannot do -- it would mean requiring bash or an awk RS="\0" pass.

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

# The loop reads from a here-document rather than a pipe so it runs in this
# shell: a pipeline's subshell would throw `unreadable` away and the scan would
# exit 0 after silently skipping a file.
#
# One awk pass per file rather than three greps: the same line can only be
# reported once per pattern, and the ordering stays file-then-line.
unreadable=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ ! -r "$f" ]; then
    printf 'cannot read, excluded from the scan: %s\n' "$f" >&2
    unreadable=1
    continue
  fi
  # The patterns are built as strings with \047 for the single quote, so this
  # awk program contains no quote character the shell would have to escape.
  awk -v file="$f" '
    BEGIN {
      # A here-doc opener: << or <<-, an optional quote, an identifier.
      open_re   = "<<-?[[:space:]]*[\"\047]?[A-Za-z_][A-Za-z0-9_]*[\"\047]?"
      # Strip the operator and quotes back off to recover the delimiter word.
      strip_re  = "^<<-?[[:space:]]*[\"\047]?"
      # A hardcoded escape sequence, or a raw COLOR_* variable the ux_*
      # wrappers exist to replace.
      color_re  = "\\\\033\\[|\\\\e\\[|\\\\x1[bB]\\[|\\$\\{?COLOR_"
      # A status word printed as plain text where a semantic ux_* call
      # belongs. Both quote styles: echo \047Done\047 is as raw as echo "Done".
      status_re = "(echo|printf)[^|]*[\"\047](Done|OK|Error|Failed|Failure|Success|Warning|Warn)"
    }
    # Inside a here-doc body every line is data, not code. Skipping to the
    # closing delimiter is what stops a << in the help text itself, or a
    # status word being *documented*, from being reported as output.
    inbody {
      line = $0
      sub(/^[[:space:]]+/, "", line)
      if (line == delim) inbody = 0
      next
    }
    # A comment is documentation, not output. Skipping them here is what keeps
    # a file that *describes* these patterns from reporting itself.
    /^[[:space:]]*#/ { next }
    {
      if (match($0, open_re)) {
        # A real delimiter word ends there. Requiring that rules out the
        # left-shift operator, where the next character is ) or a digit:
        # $((1 << n)) must not open a here-doc body and swallow the file.
        tail = substr($0, RSTART + RLENGTH, 1)
        if (tail == "" || tail == " " || tail == "\t" ||
            tail == ";" || tail == "|" || tail == "&" || tail == ">") {
          print file "\t" NR "\theredoc-help\thigh"
          delim = substr($0, RSTART, RLENGTH)
          sub(strip_re, "", delim)
          sub("[\"\047]$", "", delim)
          inbody = 1
          next
        }
      }
      if ($0 ~ color_re) {
        print file "\t" NR "\tansi-color\thigh"
        next
      }
      if ($0 ~ status_re)
        print file "\t" NR "\traw-status\tmedium"
    }
  ' "$f"
done <<SCAN_SET
$files
SCAN_SET

exit "$unreadable"
