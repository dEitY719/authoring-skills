# Bulk Review Workflow — shell-common UX Compliance Audit

Use this when asked to scan `shell-common/**/*.sh` and write findings to
`docs/abc-review-C.md`, `docs/abc-review-CX.md`, or `docs/abc-review-G.md`.

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

1. Discover files in scope (`shell-common/**/*.sh`).
2. Scan each file for violations and capture file/line evidence.
3. Categorize by severity.
4. Add concrete remediation guidance per finding.
5. Produce final review Markdown at requested path.

## Recommended Report Sections

1. Reviewer and date
2. Scope and file count
3. Findings by severity
4. Suggested fixes
5. Overall compliance summary
