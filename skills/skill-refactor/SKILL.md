---
name: skill-refactor
description: >-
  Shrink a too-long SKILL.md under 100 lines, extracting detail into
  references/. Use on "refactor my skill", "apply progressive
  disclosure", "스킬 너무 길어", "/authoring:skill-refactor", or after /authoring:skill-check
  FAIL/WARN — that audits, this rewrites.
compatibility:
  tools: Read, Glob, Grep, Write, Edit, Bash
metadata:
  model_recommendation:
    tier: sonnet
    reason: "skill refactoring: extracts references, compresses to <=100 lines, auto-generates metadata blocks per rubric SSOT"
    claude: prefer
    non_claude: advisory-only
---

# SKILL.md Progressive Disclosure Refactoring Specialist

## Help

If the argument is `-h`, `--help`, or `help`, read `references/help.md` and output its content verbatim, then stop.

## Arguments

Only `-h`/`--help`/`help` (prints help) plus an optional path to the target SKILL.md. No other flags.

> **Pattern**: All skills should place help content (usage, arguments, examples) in
> `references/help.md` and use a one-line pointer here. This keeps SKILL.md under
> the 100-line limit while making help always reachable. When refactoring a skill,
> create `references/help.md` if the skill lacks one.

## Step 1: Analyze

Read the target SKILL.md completely. Also read `references/plan-and-report-templates.md`
now — you'll need it for both the plan (Step 2) and the completion report (Step 4).

Identify:

1. **Line count** — if already ≤ 100 lines with good Progressive Disclosure structure,
   tell the user the skill passes and stop here.
2. **Extractable content** — detail, not workflow:
   - Full output templates, report format blocks
   - Reference tables, configuration examples
   - Domain knowledge, long checklists, examples > 15 lines
3. **Workflow-only content** — phases, steps, decision logic → stays in SKILL.md
4. **Existing `references/`** — check with `test -d $(dirname <path>)/references/`; if exists, list contents

## Step 2: Build Refactoring Plan

Use the plan template from `references/plan-and-report-templates.md`.
Present the plan and wait for user confirmation before writing any files.

## Step 3: Execute

After confirmation:

**3a. Create `references/` files**
- Single-responsibility per file
- Header: `# <Topic> — <purpose>`
- Under 300 lines each

**3b. Rewrite SKILL.md**
- Keep frontmatter unchanged (fix only if frontmatter has issues)
- **Naming**: never silently rewrite `name: foo:bar` → `foo-bar` to "fix"
  a VS Code diagnostic. Read `references/naming-convention.md` if the
  skill uses `category:action` colon form — that is the SSOT convention,
  preserve it byte-for-byte.
- Replace extracted blocks with pointer lines:
  `Read references/<filename>.md when <trigger condition>.`
- Compress step descriptions to action-oriented one-liners
- Verify line count ≤ 100

**3c. Validate**
- SKILL.md ≤ 100 lines?
- All `references/` files triggered from SKILL.md?
- Output format still reachable?

## Step 4: Report

Use the completion report template from `references/plan-and-report-templates.md`
(already loaded in Step 1).

Report MUST end with `[OK] refactor complete` or `[FAIL] <reason>` plus a
key=value summary (`lines_before=<n> lines_after=<n> files_created=<n>`).

Append literally as the final report line:

```
Next: /authoring:skill-check <path>
```

## Guiding Principle

SKILL.md = **control tower**: phases and pointers only.
`references/` = **knowledge base**: templates, examples, domain detail.
A user reading SKILL.md should understand the full workflow in 2 minutes.
