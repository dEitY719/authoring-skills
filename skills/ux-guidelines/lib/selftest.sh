#!/bin/sh
# selftest.sh -- one runnable check for scan-ux.sh. Builds throwaway fixtures
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
# hits <output> <pattern> -> how many rows carry that pattern name
hits() { printf '%s\n' "$1" | awk -F'\t' -v p="$2" '$3 == p' | wc -l | tr -d ' '; }
# sev <output> <pattern>  -> the severity column of that pattern's first row
sev() { printf '%s\n' "$1" | awk -F'\t' -v p="$2" '$3 == p { print $4; exit }'; }

run() {
  out=$(sh "$here/scan-ux.sh" "$@" 2>/dev/null) && st=0 || st=$?
}

mkdir -p "$work/scope/nested"

# One file per pattern, so a miss names the pattern that broke.
cat > "$work/scope/heredoc.sh" <<'FIXTURE'
#!/bin/sh
proxy_help() {
    cat <<-'EOF'
[Proxy Commands]
EOF
}
FIXTURE

cat > "$work/scope/nested/color.sh" <<'FIXTURE'
#!/bin/sh
warn() {
    echo -e "\033[31mbad\033[0m"
    echo -e "${COLOR_RED}worse${COLOR_RESET}"
}
FIXTURE

cat > "$work/scope/status.sh" <<'FIXTURE'
#!/bin/sh
run() {
    echo "Done"
    printf "Error: %s\n" "$1"
}
FIXTURE

# The compliant file: semantic calls only, nothing to report.
cat > "$work/scope/clean.sh" <<'FIXTURE'
#!/bin/sh
show() {
    ux_header "Title"
    ux_bullet "one"
    ux_success "finished"
}
FIXTURE

# 1. A directory scope walks *.sh recursively and finds each pattern.
run "$work/scope"
eq 'dir scope exits 0' "$st" 0
eq 'heredoc found' "$(hits "$out" heredoc-help)" 1
eq 'ansi found twice' "$(hits "$out" ansi-color)" 2
eq 'status found twice' "$(hits "$out" raw-status)" 2
eq 'heredoc severity' "$(sev "$out" heredoc-help)" high
eq 'ansi severity' "$(sev "$out" ansi-color)" high
eq 'status severity' "$(sev "$out" raw-status)" medium
case "$out" in
  *nested/color.sh*) ok 'walks nested directories' ;;
  *) no 'walks nested directories' "no nested/color.sh row in [$out]" ;;
esac

# 2. Every row is a four-column TSV naming a real file and a real line number.
bad=$(printf '%s\n' "$out" | awk -F'\t' 'NF != 4 || $2 !~ /^[0-9]+$/ { c++ } END { print c + 0 }')
eq 'every row is file/line/pattern/severity' "$bad" 0

# 3. A compliant file on its own reports nothing but still exits 0.
run "$work/scope/clean.sh"
eq 'clean file exits 0' "$st" 0
eq 'clean file has no rows' "$out" ''

# 4. A single file scope reports only that file.
run "$work/scope/status.sh"
eq 'single file exits 0' "$st" 0
eq 'single file rows' "$(hits "$out" raw-status)" 2
eq 'single file only' "$(hits "$out" heredoc-help)" 0

# 5. An unreadable scope is a usage error, not an empty scan -- otherwise a
#    typo'd path reads as "no violations found".
run "$work/does-not-exist"
eq 'missing scope exits 2' "$st" 2
mkdir -p "$work/empty"
run "$work/empty"
eq 'scope with no *.sh exits 2' "$st" 2

if [ "$fails" -eq 0 ]; then
  printf '\nall checks passed\n'
else
  printf '\n%s check(s) failed\n' "$fails"
fi
exit $((fails > 0))
