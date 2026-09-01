# Refactoring Playbook — Individual Function Migration

Use this when refactoring a specific help function or user-facing command output.

## Step 1: Identify Current Output Patterns

Flag these patterns:

- `cat <<EOF` blocks for help text.
- Hardcoded ANSI colors.
- Mixed style markers and inconsistent spacing.
- Plain success/error text where semantic UX functions should be used.

## Step 2: Load UX Library Safely

Prefer approved path handling and conditional loading:

```bash
if ! declare -f ux_header >/dev/null 2>&1; then
    source "${SHELL_COMMON:-$HOME/dotfiles/shell-common}/tools/ux_lib/ux_lib.sh" 2>/dev/null || true
fi
```

If the module already has standardized loading, keep that pattern.

## Step 3: Convert to Semantic UX Calls

Before:

```bash
proxy_help() {
    cat <<-'EOF'
[Proxy Commands]
check-proxy      # Run diagnostic
check-proxy env  # Environment only
EOF
}
```

After:

```bash
proxy_help() {
    ux_header "Proxy Commands"
    ux_section "Diagnostics"
    ux_bullet "check-proxy      Run diagnostic"
    ux_bullet "check-proxy env  Environment only"
    echo ""
}
```

## Step 4: Organize Information

Use this ordering:

1. Header
2. Section groupings
3. Command references or recipes
4. Warnings and notes
5. Optional divider/spacing for readability

## Step 5: Validate Output

Run targeted checks:

```bash
bash -c "source ./<target-file>.sh && <help_function>"
zsh -c "source ./<target-file>.sh && <help_function>"
```

For wider checks:

```bash
shell-common/tools/custom/check_ux_consistency.sh
```

## Suggested Commit Message Template

```text
refactor: align <function_name> output with UX guidelines

- replace hardcoded help text with ux_* functions
- standardize section structure and message semantics
- keep command behavior unchanged
```
