# Issue Template

Body of the one issue `references/issue-filing.md` files per skill. Fill it
from the snapshot that was audited — quote only lines from that copy, never
from a local working tree. Write it to a file in the run's temp dir and pass
that path to `lib/file_issue.sh`.

```
## TL;DR

`authoring:skill-check` found <F> FAIL and <W> WARN in `<path in repo>`.
Score: <pass>/<total> checks passed · Verdict: <VERDICT>

## Findings

| # | Check | Result | Notes |
|---|---|---|---|
| <id> | <name> | FAIL | <note> |
| <id> | <name> | WARN | <note> |

### FAIL: Check <N> — <Name>
**Problem:** <quote the actual SKILL.md lines>
**How to fix:** <concrete suggestion with example>

### WARN: Check <N> — <Name>
**Problem:** <specific issue>
**How to fix:** <concrete suggestion>

## Audited

- Snapshot: `<snapshot_ref>` (e.g. `upstream/main@1a2b3c4`)
- skill-check: authoring `<version>` (the `version` in this plugin's
  `.claude-plugin/plugin.json`; `unknown` when there is none — never guess a SHA)

## Verification

Re-run `/authoring:skill-check <path in repo>`: every check listed above
reports PASS (or N/A).

skill-check-key: <plugin>:<skill>
```

Rules:
- The findings table holds only WARN and FAIL rows; PASS/N/A are omitted.
- Problem/How-to-fix follow the "Issues & Improvements" rules of
  `references/report-template.md` — quote the real lines; for Check 12 name the
  helper, its inputs/outputs and the `lib/` call.
- `<path in repo>` is relative to the repo root (`skills/<name>/SKILL.md`),
  never a temp-dir or local absolute path.
- The `skill-check-key:` line stays the last line, verbatim: it is how the next
  run finds this issue instead of filing a duplicate.
