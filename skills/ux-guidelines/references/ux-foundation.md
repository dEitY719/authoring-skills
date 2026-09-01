# UX Foundation — Principles, Colors, and Semantic Functions

Source of truth: `shell-common/tools/ux_lib/UX_GUIDELINES.md`

## Core Principles

1. **Consistency**: same visual semantics across commands and modules.
2. **Discoverability**: help is available without hidden entry points.
3. **Safety**: risky operations require explicit warnings/confirmation.
4. **Feedback**: user gets clear success, warning, and error states.
5. **Readability**: output is grouped and scannable.

## Color Semantics

| Intent | Meaning | Preferred Function |
|---|---|---|
| Primary | Header and section framing | `ux_header`, `ux_section` |
| Success | Completed and valid states | `ux_success` |
| Warning | Caution, confirmation points | `ux_warning` |
| Error | Failures and blocking issues | `ux_error` |
| Info | Guidance and non-critical notes | `ux_info` |
| Muted | Dividers and secondary context | `ux_divider` |

## UX Function Catalog

```bash
ux_header "Title"
ux_section "Title"
ux_success "Message"
ux_error "Message"
ux_warning "Message"
ux_info "Message"
ux_bullet "Text"
ux_numbered "1" "Text"
ux_divider
ux_divider_thick
ux_confirm "Question"
ux_input "Prompt"
ux_menu "Item1" "Item2"
ux_table_header "Col1" "Col2" "Col3"
ux_table_row "Val1" "Val2" "Val3"
```

## Function Selection Rules

- Use `ux_bullet` for short command references.
- Use `ux_numbered` for ordered procedures.
- Use `ux_table_*` when there are stable columns.
- Use `ux_warning` and `ux_info` for caveats and tips.
- Use plain `echo ""` only as visual spacing between logical groups.

## Guardrails

- Do not hardcode ANSI escape sequences.
- Do not mix ad-hoc styles with semantic UX primitives.
- Do not add emojis in shell help output.
