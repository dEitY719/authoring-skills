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

if sh "$here/resolve-repo.sh" nope >/dev/null 2>&1; then
  no "resolve-repo missing remote" "exited 0, expected non-zero"
else
  ok "resolve-repo missing remote"
fi

cd "$work"
if sh "$here/resolve-repo.sh" >/dev/null 2>&1; then
  no "resolve-repo outside git" "exited 0, expected non-zero"
else
  ok "resolve-repo outside git"
fi

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

out=$(sh "$here/discover-refs.sh" agy "$d")
for c in definition inline-help installer help-registry help-adapter help-test bats; do
  if printf '%s\n' "$out" | cut -f1 | grep -qx "$c"; then
    ok "discover-refs category $c"
  else
    no "discover-refs category $c" "no row emitted"
  fi
done

eq "discover-refs 4 tab-separated fields" \
   "$(printf '%s\n' "$out" | awk -F'\t' 'NF!=4' | wc -l | tr -d ' ')" "0"
eq "discover-refs paths are root-relative" \
   "$(printf '%s\n' "$out" | cut -f2 | grep -c '^/' || true)" "0"
eq "discover-refs skips shaggy" \
   "$(printf '%s\n' "$out" | grep -c 'decoy.sh' || true)" "0"
eq "discover-refs finds _agy_run" \
   "$(printf '%s\n' "$out" | grep -c 'agy_helpers.sh' || true)" "1"

if sh "$here/discover-refs.sh" nosuchtoken "$d" >/dev/null 2>&1; then
  no "discover-refs no hits" "exited 0, expected 1"
else
  ok "discover-refs no hits"
fi

if sh "$here/discover-refs.sh" 'a.y' "$d" >/dev/null 2>&1; then
  no "discover-refs rejects regex metacharacters" "exited 0, expected 2"
else
  ok "discover-refs rejects regex metacharacters"
fi

# A root whose name carries regex metacharacters must still work.
odd="$work/o[d]d"
mkdir -p "$odd/shell-common/functions"
echo 'alias agy="x"' > "$odd/shell-common/functions/agy.sh"
eq "discover-refs handles a regex-ish root" \
   "$(sh "$here/discover-refs.sh" agy "$odd" | cut -f2)" "shell-common/functions/agy.sh"

if sh "$here/discover-refs.sh" agy "$work/absent" >/dev/null 2>&1; then
  no "discover-refs missing root" "exited 0, expected 2"
else
  ok "discover-refs missing root"
fi

[ "$fails" -eq 0 ] && { echo "[OK] lib selftest passed"; exit 0; }
echo "[FAIL] $fails assertion(s) failed"
exit 1
