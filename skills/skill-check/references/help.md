/authoring:skill-check — Audit a SKILL.md for structure and UX quality

Usage:
  /authoring:skill-check [path/to/SKILL.md] [--recursive]

Arguments:
  [path]    Path to the SKILL.md file to audit (optional)
            If omitted, searches for SKILL.md from the current directory

Options:
  --recursive   For composite skills, traverse the Sub-skill Model Plan deeper
                than the default 1-depth (Check 12). Off by default.
  help          Show this message

Examples:
  /authoring:skill-check
  /authoring:skill-check claude/skills/my-skill/SKILL.md
  /authoring:skill-check claude/skills/gh-issue-flow/SKILL.md --recursive
  /authoring:skill-check help

Checks run (16 total):
  Structure (1-5):    Line Count, Progressive Disclosure, Frontmatter Validity,
                      References Directory Usage, Output Report Defined
  UX Quality (6-12):  Help Flag Pattern, Step Structure, Options Documentation,
                      Verdict Output, Next-action Hint, No Emojis,
                      Executable Procedure Extraction
  Model (13):         Model Recommendation Metadata (read-only tier advice;
                      rubric: references/model-recommendation.md)
  Security (14-15):   License Declaration, Capability Declaration Consistency
                      (read-only policy alignment; pre-empts security scanners)
  Budget (16):        Description Length (PASS <=250 chars / WARN 251-400 /
                      FAIL >400; characters not bytes)
