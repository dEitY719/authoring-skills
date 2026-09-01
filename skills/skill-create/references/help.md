/authoring:skill-create — Create new skills, modify and improve existing skills.

Usage:
  /authoring:skill-create               # interactive — capture intent, draft, evaluate
  /authoring:skill-create "<idea>"      # seed with a short idea/topic
  /authoring:skill-create -h | --help | help

Phases:
  1. Capture Intent       — 4 questions about scope/triggers/output
  2. Interview & Research — edge cases, MCPs, dependencies
  3. Write SKILL.md       — references/skill-writing-guide.md
  4. Run & Evaluate       — references/eval-pipeline.md
  5. Improve              — references/improvement-philosophy.md
  6. Description Optimize — references/description-optimization.md
  7. Package              — python -m scripts.package_skill <path>
  8. Quality Gate         — /authoring:skill-check → /authoring:skill-refactor if FAIL/WARN

Final Output:
  [OK] authoring:skill-create — <name> packaged
    path=<folder>  package=<name>.skill  lines=<n>  refs=<n>
    quality_gate: PASS | needs /authoring:skill-refactor
  Next: install via Claude.ai (Settings → Skills → Upload) or commit folder
