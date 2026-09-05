---
name: skill-check
description: >-
  Audit a SKILL.md against 16 structure, UX, security, and context-budget
  checks. Use when the user says "check my skill", "audit my skill",
  "스킬 점검해줘", "/authoring:skill-check". Do NOT use for AGENTS.md, CLAUDE.md, or
  GEMINI.md — use devx:ai-context instead.
compatibility:
  tools: Read, Glob, Grep, Bash
---

# SKILL.md Quality Auditor

## Help

If the argument is `help`, read `references/help.md` and output its content verbatim, then stop.

## Step 1: Locate the File

If the user specifies a path, use it. Otherwise search for SKILL.md from the
current directory.

## Step 2: Run Sixteen Checks

Read `references/checks.md` for all 16 check definitions and PASS/WARN/FAIL/N/A criteria.
Assign one result per check. Audit-only — never stop on failure; report every check (`authoring:skill-check` is read-only and must produce a full report).

**Checks 1–5: Structure**
Line Count · Progressive Disclosure · Frontmatter Validity · References Directory · Output Report

**Checks 6–12: UX Quality**
Help Flag Pattern · Step Structure · Options Documentation · Verdict Output · Next-action Hint · No Emojis · Executable Procedure Extraction

**Check 13: Model Recommendation Metadata**
Detects/validates `metadata.model_recommendation` (tier haiku/sonnet/opus +
reason + compatibility) and reports a recommended tier per the rubric SSOT
`references/model-recommendation.md`. **Read-only — recommends a tier, never
switches models or writes files** (#809). For composite skills (body invokes
`/gh-*`, `gh:*`, `Skill(...)`), build a 1-depth Sub-skill Model Plan separate
from this skill's own tier; `--recursive` opts into deeper traversal.

Check 11 (No Emojis) consults `references/allowed-emoji-skills.txt` —
a skill whose `<plugin>:<skill>` key appears in that file resolves to `[N/A] allowlisted`.

**Checks 14–15: Security & Policy Alignment**
License Declaration · Capability Declaration Consistency

Check 14 cross-checks frontmatter `license` against a repo-root `LICENSE`
(pre-empts scanner `MANIFEST_MISSING_LICENSE`). Check 15 scans helpers across
`lib/`, legacy `scripts/`, and adjacent executables for network signals and
compares against `compatibility.network` (pre-empts
`TOOL_ABUSE_UNDECLARED_NETWORK`). Both are **read-only** — they flag a policy
gap, never edit files.

**Check 16: Description Length**
Frontmatter `description` measured in **characters, not bytes** (Korean glyphs
are 3 bytes each). PASS ≤ 250 · WARN 251–400 (needs a justifying comment) ·
FAIL > 400. Descriptions load into every session's `available_skills` listing,
which Codex/Kimi cap at ~5,440 characters across all installed skills (#1411).
Keep trigger phrases and short negative triggers; move flag semantics to
`references/help.md`, behaviour detail to Step sections, and sister-skill
cross-references to the body. Executable mirror:
`tests/bats/skills/_fixtures/skill_description_length.sh`.

## Step 3: Output the Report

Read `references/report-template.md` for the exact format.
