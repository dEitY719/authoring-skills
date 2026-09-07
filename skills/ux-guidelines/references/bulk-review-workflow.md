# Bulk Review Workflow — shell-common UX Compliance Audit

Use this when asked to scan a shell tree and write findings to
`docs/abc-review-C.md`, `docs/abc-review-CX.md`, or `docs/abc-review-G.md`.

The scope is whatever paths are passed to `lib/scan-ux.sh`. With no argument it
defaults to `$SHELL_COMMON` (itself defaulting to `$HOME/dotfiles/shell-common`),
which exists only inside the `dEitY719/dotfiles` checkout — see SKILL.md's
Objective. Pass the user's own paths when working anywhere else.

## Review Output Targets

- `abc-review-C.md`: Claude review.
- `abc-review-CX.md`: ChatGPT review.
- `abc-review-G.md`: Gemini review.

Follow the repository review format from `docs/AGENTS.md`.

## Violations to Detect

1. **Hardcoded colors**
   - Example: `echo -e "${COLOR_RED}Error${COLOR_RESET}"`
   - Expected: `ux_error "Error"`
2. **Hardcoded help output blocks**
   - Example: `cat <<EOF ... EOF`
   - Expected: structured `ux_section` + `ux_bullet`/`ux_numbered`
3. **Missing help discoverability**
   - No clear help behavior for no-argument execution
4. **Inconsistent presentation**
   - Mixed styles, uneven grouping, non-semantic status messaging
5. **Non-semantic messages**
   - Plain `echo "Done"` where intent-specific UX functions are required

## Exclusions

Do not report these as UX violations unless user-facing output is explicit:

- Utility scripts with no interactive user output.
- Thin wrappers that only delegate to external tools.
- Auto-generated files/templates.

## Severity Model

- `high`: directly violates UX foundations (hardcoded colors/format blocks).
- `medium`: partial compliance, inconsistent structure.
- `low`: minor readability or formatting issues.

## Procedure

1. Run `sh <skill-dir>/lib/scan-ux.sh [path ...]`. It emits
   `file<TAB>line<TAB>pattern<TAB>severity` rows for the three decidable
   patterns — `heredoc-help`, `ansi-color`, `raw-status` — and exits 2 rather
   than reporting an empty scan when the scope has no `*.sh` file, so a typo'd
   path never reads as "no violations found".
2. Apply the exclusions above to those rows and drop the false positives.
3. Add the findings the scanner cannot see: missing help discoverability and
   inconsistent presentation.
4. Add concrete remediation guidance per finding.
5. Produce final review Markdown at requested path.

## Recommended Report Sections

1. Reviewer and date
2. Scope and file count
3. Findings by severity
4. Suggested fixes
5. Overall compliance summary
