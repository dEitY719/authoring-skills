# Plan and Report Templates

## Refactoring Plan Template (Step 2)

Present this before writing any files. Wait for user confirmation.

```
## Refactoring Plan

Current: <path> — <N> lines
Target: ≤ 100 lines

### Extract to references/:
- [Section/block name] (~X lines) → references/<filename>.md
  Contains: <what kind of content>
  SKILL.md loads it when: <trigger condition>

### Keep in SKILL.md:
- Frontmatter (unchanged)
- Phase/step structure (workflow only)
- Pointers to each references/ file

### Expected result:
- SKILL.md: ~<N> lines (down from <current>)
- New reference files: <list>

Proceed?
```

---

## Completion Report Template (Step 4)

```
## Refactoring Complete

### SKILL.md
Before: <N> lines → After: <M> lines (↓ X%)

### References Created
- references/<file>.md — <N> lines — <what it covers>

### Validation
Copy the rows `lib/validate-refactor.sh` printed in Step 3c verbatim:

| Check              | Result    | Detail |
|--------------------|-----------|--------|
| line-count         | PASS/FAIL | <n> lines (limit 100) |
| uncited-references | PASS/FAIL | ... |
| orphan-references  | PASS/FAIL | ... |
| output-block       | PASS/FAIL | ... |

### Next step
Run /authoring:skill-check to verify the result.
```

---

## What Belongs Where

| Content type | SKILL.md | references/ |
|-------------|----------|-------------|
| Phase names and sequence | yes | |
| Decision logic (if X → do Y) | yes | |
| One-liner step descriptions | yes | |
| Pointer to reference file | yes | |
| Full output templates | | yes |
| Configuration examples (>10 lines) | | yes |
| Domain knowledge / checklists | | yes |
| Examples with before/after | | yes |
| Large reference tables | | yes |
