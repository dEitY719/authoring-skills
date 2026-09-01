# authoring:command-rename — Mapping design (F-6)

Build the old→new mapping from the Step 2 discovery set (minus the Step 4
git-family exclusions), then resolve the two interactive decisions below.
Both decisions MUST be confirmed with the user — never auto-decided.

## Mapping table format

| Old name | New name | Kind | Notes |
|----------|----------|------|-------|
| `agy` | `agent-yolo` | public alias | dash-form per §1 |
| `_agy_run` | `_agentyolo_run` | private sub-fn | prefix follows new base |
| … | … | … | … |

Include the definition site and every reference-point hit for each row (from
`references/discovery.md`) so the eventual implementer has the full blast
radius.

## Interactive decision 1 — backward compatibility

For each renamed public alias, ask the user:

- **Deprecated shim** — keep the old name as a thin alias that forwards to
  the new one (per `command-design-pattern.md` §8), optionally emitting a
  deprecation notice. Safer for muscle memory.
- **Hard removal** — delete the old name outright. Cleaner, but breaks any
  external scripts/muscle memory immediately.

Record the chosen policy per name. Do not assume a default.

## Interactive decision 2 — name collisions

If a proposed new name already exists elsewhere (another alias, function, or
PATH binary), surface the collision and ask how to resolve it (pick a
different new name, or confirm the merge is intentional). Never silently
overwrite.

## Intentionally-dropped names

List every name that will be **removed** (hard-removal choices, or obsolete
names being retired) as an explicit "Removed / dropped" section — so the
refactor issue's behavior-preservation review can account for each one.
