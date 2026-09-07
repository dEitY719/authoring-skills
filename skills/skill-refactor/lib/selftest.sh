#!/bin/sh
# selftest.sh -- one runnable check for validate-refactor.sh. Builds throwaway
# fixtures and asserts the contracts in that helper's header. Run:
# sh lib/selftest.sh

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
# row <output> <check-id>    -> the result column of that check's row
row() { printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$1 == id { print $2 }'; }
# detail <output> <check-id> -> the detail column of that check's row
detail() { printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$1 == id { print $3 }'; }

# fixture <dir> <body-line-count> -- a compliant skill of the given size,
# citing its one reference file and carrying an Output heading.
fixture() {
  mkdir -p "$1/references"
  printf 'placeholder\n' > "$1/references/help.md"
  {
    printf -- '---\nname: demo\n---\n\n'
    printf '# Demo\n\nSee `references/help.md`.\n\n'
    i=0
    while [ "$i" -lt "$2" ]; do
      printf 'filler\n'
      i=$((i + 1))
    done
    printf '\n## Output\n\n[OK] done\n'
  } > "$1/SKILL.md"
}

run() {
  out=$(sh "$here/validate-refactor.sh" "$@" 2>/dev/null) && st=0 || st=$?
}

# 1. A compliant skill: every row PASS, exit 0, measured line count reported.
fixture "$work/good" 5
run "$work/good/SKILL.md"
eq 'good exit' "$st" 0
eq 'good line-count' "$(row "$out" line-count)" PASS
eq 'good uncited' "$(row "$out" uncited-references)" PASS
eq 'good orphan' "$(row "$out" orphan-references)" PASS
eq 'good output-block' "$(row "$out" output-block)" PASS
eq 'line count is measured' "$(detail "$out" line-count)" \
  "$(awk 'END { print NR }' "$work/good/SKILL.md") lines (limit 100)"

# 2. Over the 100-line limit: line-count FAIL, exit 1.
fixture "$work/long" 200
run "$work/long/SKILL.md"
eq 'long exit' "$st" 1
eq 'long line-count' "$(row "$out" line-count)" FAIL
eq 'long others still pass' "$(row "$out" output-block)" PASS

# 3. A reference file nothing in SKILL.md names.
fixture "$work/uncited" 5
printf 'orphaned knowledge\n' > "$work/uncited/references/stray.md"
run "$work/uncited/SKILL.md"
eq 'uncited exit' "$st" 1
eq 'uncited row' "$(row "$out" uncited-references)" FAIL
case "$(detail "$out" uncited-references)" in
  *stray.md*) ok 'uncited names the file' ;;
  *) no 'uncited names the file' "got [$(detail "$out" uncited-references)]" ;;
esac

# 4. SKILL.md cites a reference file that does not exist.
fixture "$work/orphan" 5
printf '\nAlso read `references/gone.md`.\n' >> "$work/orphan/SKILL.md"
run "$work/orphan/SKILL.md"
eq 'orphan exit' "$st" 1
eq 'orphan row' "$(row "$out" orphan-references)" FAIL
case "$(detail "$out" orphan-references)" in
  *gone.md*) ok 'orphan names the file' ;;
  *) no 'orphan names the file' "got [$(detail "$out" orphan-references)]" ;;
esac

# 5. The rewrite dropped the output contract.
fixture "$work/nooutput" 5
grep -v '^## Output$' "$work/nooutput/SKILL.md" > "$work/nooutput/tmp"
mv "$work/nooutput/tmp" "$work/nooutput/SKILL.md"
run "$work/nooutput/SKILL.md"
eq 'nooutput exit' "$st" 1
eq 'nooutput row' "$(row "$out" output-block)" FAIL

# 6. A skill with no references/ directory at all is not a failure.
mkdir -p "$work/bare"
printf -- '---\nname: bare\n---\n\n# Bare\n\n## Report\n\n[OK] done\n' \
  > "$work/bare/SKILL.md"
run "$work/bare/SKILL.md"
eq 'bare exit' "$st" 0
eq 'bare uncited' "$(row "$out" uncited-references)" PASS
eq 'bare orphan' "$(row "$out" orphan-references)" PASS

# 7. Usage errors exit 2, distinct from a FAIL row.
run
eq 'no args exits 2' "$st" 2
run "$work/good/SKILL.md" extra
eq 'too many args exits 2' "$st" 2
run "$work/does-not-exist/SKILL.md"
eq 'missing file exits 2' "$st" 2

if [ "$fails" -eq 0 ]; then
  printf '\nall checks passed\n'
else
  printf '\n%s check(s) failed\n' "$fails"
fi
exit $((fails > 0))
