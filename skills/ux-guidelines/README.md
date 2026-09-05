# UX Guidelines Skill

Apply UX_GUIDELINES.md standards to shell functions and help text formatting.

Every `shell-common/...` path below is relative to the `dEitY719/dotfiles`
checkout: `$SHELL_COMMON`, which defaults to `$HOME/dotfiles/shell-common`.
Run against another repo and these paths resolve to nothing.

## Usage

```
User: "proxy_help() 함수를 UX 가이드라인에 따라 리팩토링해"
User: "새 help 함수를 만드는데 UX_GUIDELINES 규칙을 따르고 싶어"
User: "이 함수를 cc_help 스타일로 리팩토링해"
```

## Key Principles

1. **Consistency** - Same color scheme and formatting across all functions
2. **Semantic UX** - Use `ux_header()`, `ux_section()`, `ux_bullet()` instead of hardcoded text
3. **Color Semantics** - Blue for headers, cyan for info, yellow for warnings, red for errors
4. **Readability** - Well-structured sections, clear visual hierarchy
5. **Maintainability** - Easy to update and extend

## Core UX Functions

| Function | Purpose | Color |
|----------|---------|-------|
| `ux_header` | Main title with border | Blue |
| `ux_section` | Section header | Blue |
| `ux_bullet` | Bullet list item | Blue |
| `ux_numbered` | Numbered list item | Blue |
| `ux_success` | Success message | Green |
| `ux_warning` | Warning message | Yellow |
| `ux_error` | Error message | Red |
| `ux_info` | Info message | Cyan |

## What It Does

1. Analyzes current help function implementation
2. Identifies sections and logical groupings
3. Replaces hardcoded `cat <<EOF` output with UX functions
4. Loads ux_lib.sh conditionally if needed
5. Tests refactored output
6. Creates commit documenting changes

## Reference Pattern

See: `shell-common/functions/cc_help.sh`

```bash
cc_help() {
    ux_header "Claude Code Usage Commands"

    ux_section "Installation"
    ux_bullet "Global prefix: npm install -g ccusage"
    echo ""

    ux_section "Quick Commands"
    ux_table_row "ccd" "ccusage daily" "Token usage"
    echo ""
}
```

## Before & After

**Before (hardcoded text):**
```bash
proxy_help() {
    cat <<-'EOF'

[Proxy(Corporate) Commands & Diagnostics]

DIAGNOSTIC COMMANDS
  check-proxy          # Run full diagnostic
  check-proxy env      # Environment variables only
EOF
}
```

**After (UX functions):**
```bash
proxy_help() {
    ux_header "Proxy(Corporate) Commands & Diagnostics"

    ux_section "Diagnostic Commands"
    ux_bullet "check-proxy          Run full diagnostic"
    ux_bullet "check-proxy env      Environment variables only"
    echo ""
}
```

## Full Guidelines

See: `shell-common/tools/ux_lib/UX_GUIDELINES.md`
