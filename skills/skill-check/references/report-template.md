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

### Context Budget Check
| #  | Check                        | Result | Notes                                      |
|----|------------------------------|--------|--------------------------------------------|
| 16 | Description Length           | FAIL   | 668 chars > 400 — move flag detail to references/help.md |

Recommended tier: haiku — read-only audit, bounded output (declared: none yet)

Score: 6/13 checks passed (5 warnings, 2 fails, 1 N/A)
Verdict: NEEDS WORK — fix FAIL items before shipping

## Sub-skill Model Plan
(only for composite skills that invoke other skills; 1-depth unless --recursive)
This skill's own tier: sonnet — orchestration, no deep edits

| Sub-skill                | Declared tier | Notes                          |
|--------------------------|---------------|--------------------------------|
| gh:issue-implement       | opus          | deep implementation             |
| gh:commit                | haiku         | structured CLI wrapping         |
| gh:pr                    | haiku         | structured CLI wrapping         |
| gh:pr-resolve-conflict   | opus          | rebase / conflict resolution    |
| devx:schedule            | unknown       | metadata absent (WARN)          |

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
```

Rules:
- Only include WARN and FAIL items in Issues & Improvements section
- Quote actual lines from the file when describing problems
- Score denominator excludes N/A checks (16 checks total, minus any N/A)
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
