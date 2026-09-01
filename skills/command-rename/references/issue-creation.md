# authoring:command-rename — Issue creation (F-7 / F-8)

Both issues are created by **reusing [[gh-issue-create]]** — never by calling
`gh issue create` directly. That skill owns classification, template
selection, auto-labels, AI-metrics, and repo resolution; this skill only
feeds it the right context.

## Refactor issue (always)

Invoke `Skill(gh:issue-create, "<remote>")`, having first laid out the design
in the conversation so gh:issue-create's classifier lands on `refactor`:

- State the intent explicitly up front (the word "refactor", "동작 보존하며
  구조 정리") so its `references/prefix-table.md` heuristic picks
  `refactor` — matching `references/templates/refactor.md`.
- Provide enough signal to fill the refactor skeleton:
  **TL;DR / 동기 / 범위(Scope) / Before-After(the mapping table) /
  동작보존(behavior-preservation) / 리스크·롤백 / 검증 / References**.
  - 범위 = the discovery hit-list (all reference-point categories).
  - Before-After = the Step 5 mapping table + the Removed/dropped list.
  - 동작보존 = the backward-compat decision (shim vs hard removal) per name.
  - 검증 = help tests + bats that must still pass.
  - References = the three SSOT doc paths.

Do **not** recreate the refactor skeleton here — it already lives at
`claude/skills/gh-issue-create/references/templates/refactor.md`.

## Docs issue (only on a rule gap)

Only when `references/ssot-check.md` detected a gap, create a second issue via
`Skill(gh:issue-create, "<remote>")` with explicit `docs` intent (문서 자체
변경) so it selects `references/templates/docs.md`. Its content: which
convention is missing from which SSOT doc, and that the SSOT section (e.g. a
new `<tool>-<noun>` rule) needs to be authored. Do not propose final SSOT
prose — the docs issue is the place that gets designed later.

## Cross-linking

After **both** issues exist (capture each returned number/URL), link them
both ways:

```bash
gh issue comment <REFACTOR_N> --repo "$TARGET_REPO" --body "Related (rule gap): #<DOCS_N>"
gh issue comment <DOCS_N>     --repo "$TARGET_REPO" --body "Related (refactor): #<REFACTOR_N>"
```

If there is no rule gap, there is no docs issue and no cross-link — skip this
entirely.
