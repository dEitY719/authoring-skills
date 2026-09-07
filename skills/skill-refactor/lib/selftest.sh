#!/bin/sh
# selftest.sh -- one runnable check for validate-refactor.sh. Builds throwaway
# fixtures and asserts the contracts in that helper's header. Run:
# sh lib/selftest.sh
#
# The fixtures are markdown, so their backticks are code spans, not command
# substitution -- SC2016 has nothing to warn about here.
# shellcheck disable=SC2016

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
    printf -- '---\nname: demo\ndescription: a demo skill\n---\n\n'
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
eq 'good frontmatter' "$(row "$out" frontmatter)" PASS
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

# 5b. A heading that merely mentions the word does not satisfy the contract
#     (codex PR #18 BLOCKER: "## Report rationale" used to pass).
fixture "$work/mentions" 5
sed 's/^## Output$/## Report rationale/' "$work/mentions/SKILL.md" \
  > "$work/mentions/tmp"
mv "$work/mentions/tmp" "$work/mentions/SKILL.md"
run "$work/mentions/SKILL.md"
eq 'mentioning heading does not pass' "$(row "$out" output-block)" FAIL

# 5c. The forms that must keep passing.
for heading in '## Output' '## Output Format' '## Step 4: Report' '### REPORT' \
  '## Final Output' '## Step 3: Output the Report'; do
  fixture "$work/head" 5
  sed "s|^## Output\$|$heading|" "$work/head/SKILL.md" > "$work/head/tmp"
  mv "$work/head/tmp" "$work/head/SKILL.md"
  run "$work/head/SKILL.md"
  eq "heading [$heading] passes" "$(row "$out" output-block)" PASS
done

# 5d. Frontmatter corruption is caught rather than reported as PASS
#     (codex PR #18 BLOCKER: the rewrite could drop `name:` silently).
fixture "$work/noname" 5
grep -v '^name:' "$work/noname/SKILL.md" > "$work/noname/tmp"
mv "$work/noname/tmp" "$work/noname/SKILL.md"
run "$work/noname/SKILL.md"
eq 'missing name: exits 1' "$st" 1
eq 'missing name: row' "$(row "$out" frontmatter)" FAIL

# The closing `---` is line 4 of the fixture; dropping it leaves the block open.
fixture "$work/unclosed" 5
awk 'NR == 4 { next } { print }' "$work/unclosed/SKILL.md" > "$work/unclosed/tmp"
mv "$work/unclosed/tmp" "$work/unclosed/SKILL.md"
run "$work/unclosed/SKILL.md"
eq 'unclosed frontmatter row' "$(row "$out" frontmatter)" FAIL

fixture "$work/nodesc" 5
grep -v '^description:' "$work/nodesc/SKILL.md" > "$work/nodesc/tmp"
mv "$work/nodesc/tmp" "$work/nodesc/SKILL.md"
run "$work/nodesc/SKILL.md"
eq 'missing description: row' "$(row "$out" frontmatter)" FAIL

fixture "$work/nofm" 5
printf '# No frontmatter\n\n## Output\n' > "$work/nofm/SKILL.md"
run "$work/nofm/SKILL.md"
eq 'no frontmatter at all' "$(row "$out" frontmatter)" FAIL

# 6. A skill with no references/ directory at all is not a failure.
mkdir -p "$work/bare"
printf -- '---\nname: bare\ndescription: bare\n---\n\n# Bare\n\n## Report\n\n[OK] done\n' \
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
