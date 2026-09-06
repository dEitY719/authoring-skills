#!/bin/sh
# selftest.sh -- one runnable check for both helpers in this directory.
# Builds a throwaway git repo and a fake dotfiles tree, then asserts the
# contracts documented in each helper's header. Run: sh lib/selftest.sh

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
# exits <name> <expected-code> <cmd...> -- asserts the documented exit code,
# not merely "non-zero", so the 1-vs-2 split in each helper's header is real.
exits() {
  name=$1
  want=$2
  shift 2
  got=0
  "$@" >/dev/null 2>&1 || got=$?
  eq "$name" "$got" "$want"
}

# ---------- resolve-repo.sh ----------
mkdir -p "$work/repo"
(
  cd "$work/repo"
  git init -q .
  git remote add origin git@github.com:dEitY719/authoring-skills.git
  git remote add https https://github.com/dEitY719/other-repo.git
)
cd "$work/repo"
eq "resolve-repo ssh url"   "$(sh "$here/resolve-repo.sh")"        "TARGET_REPO=dEitY719/authoring-skills"
eq "resolve-repo https url" "$(sh "$here/resolve-repo.sh" https)"  "TARGET_REPO=dEitY719/other-repo"
exits "resolve-repo missing remote" 1 sh "$here/resolve-repo.sh" nope

cd "$work"
exits "resolve-repo outside git" 1 sh "$here/resolve-repo.sh"

# ---------- discover-refs.sh ----------
d=$work/dotfiles
mkdir -p "$d/shell-common/tools/integrations" "$d/shell-common/functions" \
         "$d/tests/bats" "$d/tests/integration" "$d/install"
echo 'alias agy="agent-yolo"'            > "$d/shell-common/tools/integrations/agy.sh"
echo '_agy_run() { :; }'                 > "$d/shell-common/functions/agy_helpers.sh"
echo '# DOC: agy -- run the agent'       > "$d/shell-common/tools/integrations/doc.sh"
echo 'echo "installing agy"'             > "$d/install/install_agy.sh"
echo 'HELP_DESCRIPTIONS[agy]="agent"'    > "$d/my_help.sh"
echo 'register agy'                      > "$d/zz_help_standard_adapter.sh"
echo 'def test_help_agy(): assert "agy"' > "$d/tests/integration/test_help_agy.py"
echo '@test "agy runs" { agy; }'         > "$d/tests/bats/agy.bats"
echo 'alias shaggy="dog"'                > "$d/shell-common/functions/decoy.sh"

outf=$work/out.tsv
sh "$here/discover-refs.sh" agy "$d" > "$outf"
for c in definition inline-help installer help-registry help-adapter help-test bats; do
  if cut -f1 "$outf" | grep -qx "$c"; then
    ok "discover-refs category $c"
  else
    no "discover-refs category $c" "no row emitted"
  fi
done

eq "discover-refs 4 tab-separated fields" \
   "$(awk -F'\t' 'NF!=4' "$outf" | wc -l | tr -d ' ')" "0"
eq "discover-refs paths are root-relative" \
   "$(cut -f2 "$outf" | grep -c '^/' || true)" "0"
eq "discover-refs skips shaggy" \
   "$(grep -c 'decoy.sh' "$outf" || true)" "0"
eq "discover-refs finds _agy_run" \
   "$(grep -c 'agy_helpers.sh' "$outf" || true)" "1"

exits "discover-refs no hits" 1 sh "$here/discover-refs.sh" nosuchtoken "$d"
exits "discover-refs rejects regex metacharacters" 2 sh "$here/discover-refs.sh" 'a.y' "$d"

# `help` is a family token, not a synonym for --help: this must scan (and hit
# `test_help_agy.py`) rather than print a usage line and exit 0.
eq "discover-refs treats 'help' as a token" \
   "$(sh "$here/discover-refs.sh" help "$d" | cut -f1 | sort -u | tr '\n' ',')" \
   "help-test,"

# A root whose name carries regex metacharacters must still work.
odd="$work/o[d]d"
mkdir -p "$odd/shell-common/functions"
echo 'alias agy="x"' > "$odd/shell-common/functions/agy.sh"
eq "discover-refs handles a regex-ish root" \
   "$(sh "$here/discover-refs.sh" agy "$odd" | cut -f2)" "shell-common/functions/agy.sh"

exits "discover-refs missing root" 2 sh "$here/discover-refs.sh" agy "$work/absent"

[ "$fails" -eq 0 ] || { echo "[FAIL] $fails assertion(s) failed"; exit 1; }
echo "[OK] lib selftest passed"
