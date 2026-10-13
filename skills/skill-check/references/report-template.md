# Report Template

Use this exact format when outputting the audit report.

```
## SKILL.md Audit Report
File: <path>
Lines: <count>
References dir: <exists / missing>

### Structure Checks
| # | Check                        | Result | Notes                           |
|---|------------------------------|--------|---------------------------------|
| 1 | Line Count                   | PASS   | 42 lines — within 100-line goal |
| 2 | Progressive Disclosure       | WARN   | templates inline, not in refs/  |
| 3 | Frontmatter Validity         | PASS   | name, description valid         |
| 4 | References Directory Usage   | FAIL   | no references/ directory        |
| 5 | Output Report Defined        | PASS   | template in Step 3              |

### UX Quality Checks
| #  | Check                        | Result | Notes                                 |
|----|------------------------------|--------|---------------------------------------|
| 6  | Help Flag Pattern            | PASS   | -h/--help → references/help.md        |
| 7  | Step Structure               | WARN   | steps present but no stop-on-error    |
| 8  | Options Documentation        | N/A    | skill takes no arguments              |
| 9  | Verdict Output               | FAIL   | output ends without [OK]/[FAIL]       |
| 10 | Next-action Hint             | PASS   | teardown shown in success report      |
| 11 | No Emojis                    | PASS   | no emoji glyphs in body or references |
| 12 | Executable Procedure Extraction | WARN | repeated fallback should move to lib/ |

### Model Recommendation Check
| #  | Check                        | Result | Notes                                 |
|----|------------------------------|--------|---------------------------------------|
| 13 | Model Recommendation Metadata| WARN   | metadata absent (migration period)    |

### Security & Policy Alignment Checks
| #  | Check                          | Result | Notes                                      |
|----|--------------------------------|--------|--------------------------------------------|
| 14 | License Declaration            | WARN   | no license; repo LICENSE exists → add MIT  |
| 15 | Capability Declaration Consistency | WARN | lib/scripts helper imports requests; network undeclared |
| 19 | Credential-to-Network Flow     | PASS   | no secret reaches a network call           |

### Context Budget Check
| #  | Check                        | Result | Notes                                      |
|----|------------------------------|--------|--------------------------------------------|
| 16 | Description Length           | FAIL   | 668 chars > 400 — move flag detail to references/help.md |

### Portability Checks
| #  | Check                        | Result | Notes                                      |
|----|------------------------------|--------|--------------------------------------------|
| 17 | Bundle Self-containment      | WARN   | 1 path(s) outside the skill dir: references/a.md:4 -> ../../../lib/x.sh |
| 18 | Plugin-root Fallback         | N/A    | no CLAUDE_PLUGIN_ROOT expansion            |

Recommended tier: haiku — read-only audit, bounded output (declared: none yet)

Score: 7/17 checks passed (7 warnings, 3 fails, 2 N/A)
Verdict: NEEDS WORK — fix FAIL items before shipping

## Sub-skill Model Plan
(only for composite skills that invoke other skills; 1-depth unless --deep-subskills)
This skill's own tier: sonnet — orchestration, no deep edits

| Sub-skill           | Declared tier | Notes                        |
|---------------------|---------------|------------------------------|
| gh-issue:implement  | opus          | deep implementation          |
| gh-pr:commit        | haiku         | structured CLI wrapping      |
| gh-pr:create        | haiku         | structured CLI wrapping      |
| gh-resolve:conflict | opus          | rebase / conflict resolution |
| session:schedule    | unknown       | metadata absent (WARN)       |

## Issues & Improvements

### FAIL: Check N — <Name>
**Problem:** <quote specific lines from the file>
**How to fix:** <concrete suggestion with example>

### WARN: Check N — <Name>
**Problem:** <specific issue>
**How to fix:** <concrete suggestion>
For Check 12, name the helper to extract, its inputs/outputs, and the direct `lib/` call pattern.

## Next Actions
1. <highest priority fix>
2. <next fix>
Run /authoring:skill-check again after fixes to verify.
<only when Check 15 or 19 is WARN:>
Confirm with the real security scanner -- it, not this audit, is the source of truth:
  uvx --from cisco-ai-skill-scanner skill-scanner scan-all <skills-dir> --use-behavioral --format json --output-json /tmp/skill-scan.json
```

Rules:
- Only include WARN and FAIL items in Issues & Improvements section
- Quote actual lines from the file when describing problems
- Score denominator excludes N/A checks (19 checks total, minus any N/A)
- Check 16 always reports the measured character count in Notes, so the
  overage is actionable without re-running a measurement
- The "Model Recommendation Check" table row + "Recommended tier" line are
  always shown; the "Sub-skill Model Plan" section appears only for composite
  skills (omit it entirely for leaf skills)
- Verdict labels:
  - All applicable checks PASS → `EXCELLENT — gold standard`
  - ≥80% PASS, no FAIL → `GOOD — production-ready, minor polish needed`
  - ≥60% PASS or any FAIL → `NEEDS WORK — fix FAIL items before shipping`
  - <60% PASS → `POOR — significant gaps, major rework needed`
- Always end with "Next Actions" section listing concrete fixes in priority order

## Batch Mode Output (`-d` / `-r` / `-R`)

Batch runs do not print the per-skill report above; each skill's detail goes
into its issue body (`references/issue-template.md`). Print instead:

```
## Batch Summary
| Repo              | Skill        | Score | Verdict    | FAIL | WARN | Issue        |
|-------------------|--------------|-------|------------|------|------|--------------|
| authoring-skills/ | skill-check  | 17/17 | EXCELLENT  | 0    | 0    | —            |
| gh-flow-skills/   | wave         | 14/17 | NEEDS WORK | 1    | 2    | NEW          |
| gh-pr-skills/     | merge        | 15/17 | GOOD       | 0    | 2    | EXISTS #41   |
| plain-skills/     | notes        | 16/17 | GOOD       | 0    | 1    | SKIP no remote |
| jira-skills-claude-1/ | —        | —     | —          | —    | —    | DUP same target as jira-skills/ |

## Issue Plan
| Target repo                    | Title                                                | FAIL | WARN | Status     |
|--------------------------------|------------------------------------------------------|------|------|------------|
| github.com dEitY719/gh-flow-skills | fix(wave): skill-check findings — 1 FAIL, 2 WARN | 1    | 2    | NEW        |
| github.com dEitY719/gh-pr-skills   | refactor(merge): skill-check findings — 0 FAIL, 2 WARN | 0 | 2  | EXISTS #41 |
Snapshot: <snapshot_ref per repo; any `stale:<date>` ref is called out here as a warning>

[OK] audited <n> skills in <m> repos — issues: <new> new, <exists> existing, <skip> skipped

## Next Actions
1. <highest priority fix across the batch>
Run /authoring:skill-check -d <repo> --no-issue after fixes to verify.
```

Rules:
- The Issue Plan is printed before the confirmation question; with
  `--no-issue` it is omitted and the Issue column shows `—`.
- After filing, replace each `NEW` with the created `NEW #N <url>`; rows not
  reached after a gh failure show `PENDING`, and the verdict line becomes
  `[FAIL] ... — <k> pending, re-run to file them`.
- `DUP` and `SKIP` rows of the scanner (`skill_md` = `-`) appear in the Batch
  Summary with `—` scores.
