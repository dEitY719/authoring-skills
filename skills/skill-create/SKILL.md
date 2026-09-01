---
name: skill-create
description: Create a skill, or improve and evaluate an existing one. Use to build one from scratch, edit or optimize it, run evals or benchmarks, tune a description for triggering accuracy, or on "스킬 만들어줘", "/authoring:skill-create". Authoring — authoring:skill-check audits.
metadata:
  model_recommendation:
    tier: sonnet
    reason: "new skill generation with interactive interview, draft, eval loop, and description optimization"
    claude: prefer
    non_claude: advisory-only
---

# Skill Creator

## Help

If args is `-h`/`--help`/`help`, read `references/help.md` verbatim and stop.

A skill for creating new skills and iteratively improving them. Figure out where the user is in the process and help them progress. Be flexible — if user says "just vibe with me", skip the eval loop.

## Core Loop

1. Decide what the skill should do
2. Run the executable-first gate: deterministic, repetitive, parse/validate, scaffold, fallback, and aggregation flows belong in `lib/*.sh` or `lib/*.py`, not prose
3. Write a draft
4. Run claude-with-access-to-the-skill on test prompts
5. Evaluate results (qualitative + quantitative) with the user
6. Improve the skill based on feedback
7. Repeat until satisfied
8. Optimize description for triggering accuracy
9. Package the final skill
10. Run `/authoring:skill-check` → if FAIL/WARN, run `/authoring:skill-refactor` (quality gate)

Each phase produces an artifact (intent, helper plan, draft, eval results). On a clear blocker (e.g., test prompts unwriteable, `package_skill` fails), stop and report — do not advance silently.

## Phase 1: Capture Intent

Extract answers from conversation history first if the user says "turn this into a skill".

1. What should this skill enable Claude to do?
2. When should this skill trigger? (what user phrases/contexts)
3. What's the expected output format?
4. Should we set up test cases? (suggest based on skill type — objective outputs benefit, subjective ones often don't)

## Phase 2: Interview and Research

Proactively ask about edge cases, input/output formats, example files, success criteria, and dependencies.
Check available MCPs for research. Wait to write test prompts until ironed out. Before drafting, classify
candidate helpers — file creation/conversion, repeated CLI calls, multi-step fallback, parsing/validation,
calculation/aggregation, reproducible scaffolds — and leave prose for judgment, policy, and explanation.

## Phase 3: Write the SKILL.md

Read `references/skill-writing-guide.md` for anatomy, progressive disclosure, writing
patterns, frontmatter fields, communication style, executable-first extraction rules, and test case format.

## Phase 4: Run and Evaluate Test Cases

Read `references/eval-pipeline.md` for the full pipeline: spawning runs, drafting assertions,
capturing timing, grading, benchmark aggregation, the high-variance analyst pass, and the viewer.

IMPORTANT: Always generate the eval viewer using `eval-viewer/generate_review.py` BEFORE
evaluating outputs yourself — get results in front of the human ASAP.

## Phase 5: Improve the Skill

Read `references/improvement-philosophy.md` for guidance on generalizing from feedback,
keeping prompts lean, explaining the why, and promoting repeated manual or fallback work into helpers.

## Phase 6: Description Optimization
Read `references/description-optimization.md` for the trigger eval query generation, HTML
review flow, optimization loop script, and triggering mechanics.

## Phase 7: Package and Present

If `present_files` is available, run `python -m scripts.package_skill <path>`, then point the
user to the resulting `.skill` file path so they can install it. When helpers exist, show direct
call patterns such as `bash claude/skills/<name>/lib/<script>.sh` or `python claude/skills/<name>/lib/<script>.py`.

## Phase 8: Post-Creation Quality Gate

Run `/authoring:skill-check` on the new SKILL.md. If any check returns FAIL or WARN, immediately run
`/authoring:skill-refactor` to bring it under 100 lines with proper Progressive Disclosure structure.
Report before/after line counts to the user.

## Final Output
```
[OK] authoring:skill-create — <name> packaged
  path=<folder>  package=<name>.skill  lines=<n>  refs=<n>
  quality_gate: PASS | needs /authoring:skill-refactor
Next: install via Claude.ai (Settings → Skills → Upload) or commit folder
```

## Platform-Specific Instructions

Read `references/platform-instructions.md` when running in Claude.ai or Cowork.

## Reference Files
Phases cite each `references/*.md` inline. Also: `references/schemas.md` (JSON for evals.json/
grading.json), `references/local-patches.md` (this copy's local fixes and why it is not re-synced)
and `agents/{grader,comparator,analyzer}.md` (assertion eval, blind A/B, why-one-won).
