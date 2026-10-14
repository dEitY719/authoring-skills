#!/usr/bin/env bats
# tests/bats/skill_check_description_length.bats
# Verify Check 16 (Description Length) as implemented by
#   skills/skill-check/lib/skill_check.sh
# and documented in skills/skill-check/references/checks.md.
# Helpers: fixtures/skill_description_length.sh (wrappers over the real script).
#
# Moved from dEitY719/dotfiles tests/bats/skills/ (dEitY719/dotfiles#2200);
# originally pinned issue dEitY719/dotfiles#1411:
#   F-1  frontmatter description is extracted for both single-line and
#        folded (`>-`) forms, collapsed to one whitespace-normalised line
#   F-2  extraction stops at the next top-level key, never swallowing
#        allowed-tools / compatibility / metadata
#   F-3  length is counted in CHARACTERS, not bytes (Korean triggers are
#        3 bytes per glyph -- byte counting would over-report by ~3x)
#   F-4  verdict boundaries: PASS <= 250 | WARN 251-400 (PASS when a
#        `# check 16` comment justifies it) | FAIL > 400
#   F-5  a skill with no description yields N/A (Check 3 owns that)

load 'test_helper'

setup() {
    # shellcheck source=fixtures/skill_description_length.sh
    source "${REPO_ROOT}/tests/bats/fixtures/skill_description_length.sh"
    SKILL_MD="${BATS_TEST_TMPDIR}/SKILL.md"
}

# ---- fixture builders ----------------------------------------------------

_seed_single_line() {
    cat >"$SKILL_MD" <<'MD'
---
name: demo-one
description: Short single-line description.
allowed-tools: Bash, Read
---

# demo
MD
}

_seed_folded() {
    cat >"$SKILL_MD" <<'MD'
---
name: demo-folded
description: >-
  First line of the folded description.
  Second line continues it.
  Third line ends it.
allowed-tools: Bash
---

# demo
MD
}

_seed_folded_then_metadata() {
    cat >"$SKILL_MD" <<'MD'
---
name: demo-meta
description: >-
  Only this sentence belongs to the description.
metadata:
  model_recommendation:
    tier: sonnet
    reason: "this must never be counted as description text"
compatibility:
  tools: Read
---

# demo
MD
}

_seed_korean() {
    # 6 characters / 12 bytes -- proves character counting, not byte counting.
    cat >"$SKILL_MD" <<'MD'
---
name: demo-kor
description: 가나다abc
---

# demo
MD
}

_seed_no_description() {
    cat >"$SKILL_MD" <<'MD'
---
name: demo-none
allowed-tools: Bash
---

# demo
MD
}

_seed_of_length() {
    # $1 = description character count (ASCII); $2 = optional frontmatter line
    local _body
    _body="$(printf 'x%.0s' $(seq 1 "$1"))"
    {
        printf -- '---\n'
        printf 'name: demo-len\n'
        [ -z "${2:-}" ] || printf '%s\n' "$2"
        printf 'description: %s\n' "$_body"
        printf -- '---\n\n# demo\n'
    } >"$SKILL_MD"
}

# ---- F-1: extraction, both frontmatter forms ----------------------------

@test "extract: single-line description is counted verbatim" {
    _seed_single_line
    run skill_desc_length "$SKILL_MD"
    assert_success
    assert_output '30' # 'Short single-line description.'
}

@test "extract: folded description is collapsed to one line" {
    _seed_folded
    run skill_desc_length "$SKILL_MD"
    assert_success
    # 'First line of the folded description. Second line continues it. Third line ends it.'
    assert_output '83'
}

# ---- F-2: extraction stops at the next top-level key --------------------

@test "extract: does not swallow allowed-tools" {
    _seed_single_line
    run skill_desc_verdict "$SKILL_MD"
    assert_success
    assert_output 'PASS'
    run skill_desc_length "$SKILL_MD"
    assert_output '30'
}

@test "extract: does not swallow metadata or compatibility blocks" {
    _seed_folded_then_metadata
    run skill_desc_length "$SKILL_MD"
    assert_success
    assert_output '46' # 'Only this sentence belongs to the description.'
}

# ---- F-3: characters, not bytes -----------------------------------------

@test "length: Korean glyphs count as characters, not bytes" {
    _seed_korean
    run skill_desc_length "$SKILL_MD"
    assert_success
    # '가나다abc' is 6 characters but 12 bytes; byte counting would say 12.
    assert_output '6'
}

# ---- F-4: verdict boundaries --------------------------------------------

@test "verdict: 250 characters is the PASS ceiling" {
    _seed_of_length 250
    run skill_desc_length "$SKILL_MD"
    assert_output '250'
    run skill_desc_verdict "$SKILL_MD"
    assert_success
    assert_output 'PASS'
}

@test "verdict: 251 characters crosses into WARN" {
    _seed_of_length 251
    run skill_desc_verdict "$SKILL_MD"
    assert_success
    assert_output 'WARN'
}

@test "verdict: 400 characters is the WARN ceiling" {
    _seed_of_length 400
    run skill_desc_verdict "$SKILL_MD"
    assert_success
    assert_output 'WARN'
}

@test "verdict: 401 characters is FAIL" {
    _seed_of_length 401
    run skill_desc_verdict "$SKILL_MD"
    assert_success
    assert_output 'FAIL'
}

@test "verdict: a check-16 comment turns the 251-400 band into PASS" {
    _seed_of_length 300 '# check 16: long trigger list is load-bearing'
    run skill_desc_verdict "$SKILL_MD"
    assert_success
    assert_output 'PASS'
}

@test "verdict: a check-16 comment does not excuse going over 400" {
    _seed_of_length 401 '# check 16: long trigger list is load-bearing'
    run skill_desc_verdict "$SKILL_MD"
    assert_success
    assert_output 'FAIL'
}

# ---- F-5: missing description is Check 3's business, not Check 16's -----

@test "verdict: missing description reports N/A instead of PASS" {
    _seed_no_description
    run skill_desc_verdict "$SKILL_MD"
    assert_success
    assert_output 'N/A'
}

@test "length: missing description reports failure instead of 0" {
    _seed_no_description
    run skill_desc_length "$SKILL_MD"
    assert_failure
}
