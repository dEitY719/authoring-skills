#!/usr/bin/env bash
# tests/bats/fixtures/skill_description_length.sh
# Thin wrappers over the canonical Check 16 (Description Length):
#   skills/skill-check/lib/skill_check.sh  (criteria: references/checks.md)
#
# No hand copy of the extraction or thresholds lives here: each helper runs
# the shipped skill_check.sh on a SKILL.md and reads its Check 16 row, so a
# change to the real check is what these tests see.
#
# Requires REPO_ROOT (set by tests/bats/test_helper.bash).

SKILL_CHECK_SH="${REPO_ROOT}/skills/skill-check/lib/skill_check.sh"

# skill_desc_row <skill_md> -- echo "<RESULT><TAB><note>" of Check 16.
skill_desc_row() {
    sh "$SKILL_CHECK_SH" "$1" | awk -F '\t' '$1 == "16" { print $2 "\t" $3 }'
}

# skill_desc_verdict <skill_md> -- echo PASS | WARN | FAIL | N/A.
skill_desc_verdict() {
    skill_desc_row "$1" | cut -f1
}

# skill_desc_length <skill_md> -- echo the description length in characters.
# Returns 1 when the file has no description (Check 16 reports N/A; Check 3
# owns that failure).
skill_desc_length() {
    local _row
    _row=$(skill_desc_row "$1")
    case "$_row" in
    N/A* | '') return 1 ;;
    esac
    printf '%s\n' "$_row" | cut -f2 | awk '{ print $1 }'
}
