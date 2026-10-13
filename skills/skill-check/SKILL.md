---
name: skill-check
description: >-
  Audit a SKILL.md, a repo, or every repo under a dir on 19 checks; batch runs
  file an issue per failing skill. Use for "check my skill", "audit all
  skills", "스킬 점검해줘", "/authoring:skill-check". Not for
  AGENTS.md/CLAUDE.md — use harness:ai-context.
compatibility:
  tools: Read, Glob, Grep, Bash
  network: required
metadata:
  model_recommendation:
    tier: sonnet
    reason: "19-criteria SKILL.md audit across four reference files; judgment on WARN/FAIL boundaries and sub-skill tier planning"
    claude: prefer
    non_claude: advisory-only
license: MIT
---

# SKILL.md Quality Auditor

## Help

If the argument is `-h`, `--help`, or `help`, read `references/help.md` and output its content verbatim, then stop.

`<skill-dir>` is this skill's installed directory, never the audited repo.

## Step 0: Parse Arguments

```sh
sh <skill-dir>/lib/skill_scan.sh args <arguments...>
```

Prints `mode target issue yes deep` (TSV). Exit 2 is a usage error: print its
message and stop. Modes: `single` (a path or skill name), `dir` (`-d`), `repo`
(`-r`), `recursive` (`-R`). Issue filing is on by default only in batch modes;
single mode files only with `--issue`, so callers such as
`/authoring:skill-create` and `/authoring:skill-refactor` never file one.

## Step 1: Locate the Files

- **single** — a path or `plugin:skill` / `skill` name:
  `sh <skill-dir>/lib/skill_scan.sh resolve <target>`; no target → search
  for SKILL.md from the current directory. Exit 2 (not found, ambiguous): stop.
- **batch** (`dir`/`repo`/`recursive`), or single with `--issue` — read
  `references/batch-mode.md` and build the audit list with
  `skill_scan.sh scan`. With issue filing on, it audits the issue target's
  default-branch snapshot, never the working tree.

## Step 2: Run Nineteen Checks

Run the mechanical half first, once per SKILL.md:

```sh
sh <skill-dir>/lib/skill_check.sh <path>
```

It decides the eight mechanical checks (1, 11, 13, 14, 15, 16, 17, 18). Read
`references/checks.md` for all 19 check definitions and PASS/WARN/FAIL/N/A
criteria, and judge the remaining eleven (2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 19)
yourself. Re-run with those eleven results appended, in check-id order, to get
the combined score/verdict row. Audit-only — never stop on failure; report
every check. Batch runs fan out one subagent per repo (`references/batch-mode.md`).

**Checks 1–5: Structure**
Line Count · Progressive Disclosure · Frontmatter Validity · References Directory · Output Report

**Checks 6–12: UX Quality**
Help Flag Pattern · Step Structure · Options Documentation · Verdict Output · Next-action Hint · No Emojis · Executable Procedure Extraction

**Checks 13–16: Model, Security, Budget**
Model Recommendation Metadata (always report a recommended tier, plus a
Sub-skill Model Plan for composite skills; `--deep-subskills` walks it past
1-depth) · License Declaration · Capability Declaration Consistency ·
Description Length — definitions and thresholds in `references/checks.md`.

**Checks 17–18: Portability** (WARN-only)
Bundle Self-containment · Plugin-root Fallback — does the skill still run
when another harness installs just this one directory.

**Check 19: Credential-to-Network Flow** (model-judged, WARN-only)
Does a secret read by a helper reach a network call — a security-scanner
HIGH finding on its own.

## Step 3: Output the Report

Read `references/report-template.md` for the exact format: the per-skill
report in single mode, the Batch Summary and Issue Plan in batch mode.

## Step 4: File Issues (batch, or single with `--issue`)

Skip when issue filing is off. Otherwise read `references/issue-filing.md`:
one issue per skill with any FAIL/WARN, sent upstream first (origin when there
is no upstream), deduplicated by its `skill-check-key:` line, created by
`lib/file_issue.sh` one at a time — only after the Issue Plan is confirmed
once (`-y` skips the question). This skill never edits files and never pushes;
the issues are its only external write.
