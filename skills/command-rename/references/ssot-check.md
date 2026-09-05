# authoring:command-rename — SSOT check & rule-gap detection (F-3 / F-4)

Read all three naming SSOT docs, compare the requested convention against
what they codify, and decide whether a **rule gap** exists. Cite each doc by
path in the issue body. Never invent SSOT text — only report gaps.

## Docs to read (cite all three by path)

All three live in the `dEitY719/dotfiles` checkout — `$DOTFILES_ROOT`, default
`$HOME/dotfiles`. Against any other repo they resolve to nothing: say so and
stop rather than reporting "no rule gap" from an unread SSOT.

1. **`docs/.ssot/command-design-pattern.md`** — §1 naming table:
   - public function → `snake_case`
   - private sub-function → `_<prefix>_<verb>`
   - public alias → **dash-form**
   - help function → `_<prefix>_help` (inline) or `<topic>_help` + `<topic>-help` (standalone)
   - §8 covers the deprecated-shim/backward-compat pattern (used in Step 5).

2. **`docs/.ssot/command-guidelines.md`** — help UX: canonical `<topic>-help`
   entry point, 15-line help budget, `ux_bullet` / `ux_bullet_sub` output.

3. **`docs/.ssot/command-delivery-model.md`** — the function vs
   PATH-executable delivery axis. **Out of scope** for a rename: the mapping
   must not move a command across this axis. Read it only to avoid crossing
   it by accident, then note "delivery model unchanged" in the issue.

## Rule-gap detection

A rule gap exists when the user's requested convention is **not literally
covered** by an existing SSOT section.

- If the request is "dash-form" for a public alias → covered by §1, **no gap**.
- Example gap (true as of this writing): a request for an arbitrary
  `<tool>-<noun>` naming scheme is **not** codified — there is currently **no
  §1.1 or any section** formally defining a `<tool>-<noun>` convention beyond
  the existing alias dash-form rule. That is a rule gap.

On a gap: record it (which convention, which doc it would belong in) and
trigger the `docs` issue in Step 6. Do **not** write proposed SSOT text into
the SSOT — the `docs` issue is where that gets designed later.
