# authoring:command-rename — Constraints

- **Never edit or commit source files.** This skill designs a mapping and
  files issues only. All searching is read-only (`grep`/`Read`). The actual
  rename happens later via `/gh-flow:issue <refactor-issue>`.
- **Never skip the git-family exclusion.** `gb`, `gwt`, and other
  high-frequency git abbreviations are always dropped from rename candidates,
  regardless of the requested convention (`references/discovery.md`).
- **Never invent SSOT rule text.** If the requested convention isn't codified
  in an existing SSOT section, report it as a rule gap and file a `docs`
  issue — do not write proposed rules into the SSOT docs
  (`references/ssot-check.md`).
- **Always confirm backward-compat + collision decisions with the user
  before creating issues.** Deprecated-shim vs hard-removal, and any name
  collision, are interactive — never auto-decided (`references/mapping-design.md`).
- **The `docs` issue is gap-only.** When there is no rule gap, create just the
  `refactor` issue — no docs issue, no cross-link.
- **Reuse [[gh-issue-create]] for issue creation.** Never call
  `gh issue create` directly; let that skill own templates, labels, and
  metrics (`references/issue-creation.md`).
- **Do not cross the delivery-model axis.** The mapping must not move a
  command between function and PATH-executable delivery
  (`command-delivery-model.md`) — renames stay on the naming axis only.
- **No delivery/behavior change.** A rename preserves behavior; the issue's
  동작보존 section must state so, and the mapping must not alter what a command
  does — only what it is called.
