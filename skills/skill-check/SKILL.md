---
name: skill-check
description: >-
  Audit a SKILL.md against 16 structure/UX/security/budget checks. Use when
  the user says "check my skill", "audit my skill", "스킬 점검해줘",
  "/authoring:skill-check". Do NOT use for AGENTS.md/CLAUDE.md/GEMINI.md — use
  harness:ai-context instead.
compatibility:
  tools: Read, Glob, Grep, Bash
metadata:
  model_recommendation:
    tier: sonnet
    reason: "16-criteria SKILL.md audit across four reference files; judgment on WARN/FAIL boundaries and sub-skill tier planning"
    claude: prefer
    non_claude: advisory-only
license: MIT
---

# SKILL.md Quality Auditor

## Help

If the argument is `-h`, `--help`, or `help`, read `references/help.md` and output its content verbatim, then stop.

## Step 1: Locate the File

If the user specifies a path, use it. Otherwise search for SKILL.md from the
current directory.

## Step 2: Run Sixteen Checks

Run the mechanical half first. `<skill-dir>` is this skill's own installed
directory, never a path inside the repository being audited:

```sh
sh <skill-dir>/lib/skill_check.sh <path>
```

It decides the six mechanical checks (1, 11, 13, 14, 15, 16). Read
`references/checks.md` for all 16 check definitions and PASS/WARN/FAIL/N/A
criteria, and judge the remaining ten (2, 3, 4, 5, 6, 7, 8, 9, 10, 12)
yourself. Re-run with those ten results appended, in check-id order, to get
the combined score/verdict row. Audit-only — never stop on failure; report
every check (`authoring:skill-check` is read-only and must produce a full
report).

**Checks 1–5: Structure**
Line Count · Progressive Disclosure · Frontmatter Validity · References Directory · Output Report

**Checks 6–12: UX Quality**
Help Flag Pattern · Step Structure · Options Documentation · Verdict Output · Next-action Hint · No Emojis · Executable Procedure Extraction

**Checks 13–16: Model, Security, Budget**
Model Recommendation Metadata (always report a recommended tier, plus a
Sub-skill Model Plan for composite skills — required report content, not
optional) · License Declaration · Capability Declaration Consistency ·
Description Length — all read-only; definitions and thresholds in
`references/checks.md`.

## Step 3: Output the Report

Read `references/report-template.md` for the exact format.
