/authoring:skill-check — Audit SKILL.md files for structure and UX quality

Usage:
  /authoring:skill-check [path/to/SKILL.md | plugin:skill | skill] [--issue] [--deep-subskills]
  /authoring:skill-check -d <dir> | -r <git-url> | -R <root> [--no-issue] [-y]

Options:

| Option | Description | Default |
|---|---|---|
| `[path \| skill-name]` | SKILL.md, a skill directory, or `plugin:skill` / `skill` (a leading `/` is dropped) | search from the current directory |
| `-d, --dir <dir>` | every skill under a directory (a repo) | — |
| `-r, --repo <git-url>` | shallow-clone the URL to a temp dir and audit every skill | — |
| `-R, --recursive <root>` | every git repo directly under `<root>` | — |
| `--issue` | single mode: opt in to filing an issue | off |
| `--no-issue` | batch mode: file nothing, audit the working tree (read-only) | batch: on |
| `-y, --yes` | skip the Issue Plan confirmation (unattended runs) | off |
| `--deep-subskills` | traverse the Check 13 Sub-skill Model Plan deeper than 1-depth (was `--recursive`) | off (1-depth) |
| `-h`, `--help`, `help` | Print this help and stop | — |

Examples:
  /authoring:skill-check
  /authoring:skill-check skills/my-skill/SKILL.md
  /authoring:skill-check gh-flow:wave
  /authoring:skill-check skills/my-composite-skill/SKILL.md --deep-subskills
  /authoring:skill-check -d ~/src/my-skills/
  /authoring:skill-check -r https://example.com/owner/my-skills.git --no-issue
  /authoring:skill-check -R ~/src/ -y
  /authoring:skill-check help

Issues (batch modes, or single with --issue):
  One issue per skill with any FAIL/WARN, filed on the `upstream` remote's repo,
  or on `origin` when there is no upstream. The audit then reads that target's
  default-branch snapshot, not the local working tree. An open issue with the
  same `skill-check-key:` line is reused (EXISTS), so a re-run files nothing new.
  The Issue Plan is shown and confirmed once before anything is filed.
  `-r` files on the URL's repo (or its fork parent). A GHES-to-github.com
  mirror is not a fork: to reach the real upstream, use `-d` on a local
  checkout that has an `upstream` remote.

Migration: `--recursive` now walks repos under a directory. The old
`<path> --recursive` (Check 13 Sub-skill Model Plan depth) is `--deep-subskills`;
the old form exits 2 with that hint.

Checks run (19 total):
  Structure (1-5):    Line Count, Progressive Disclosure, Frontmatter Validity,
                      References Directory Usage, Output Report Defined
  UX Quality (6-12):  Help Flag Pattern, Step Structure, Options Documentation,
                      Verdict Output, Next-action Hint, No Emojis,
                      Executable Procedure Extraction
  Model (13):         Model Recommendation Metadata (read-only tier advice;
                      rubric: references/model-recommendation.md)
  Security (14-15, 19): License Declaration, Capability Declaration
                      Consistency, Credential-to-Network Flow (19 is
                      model-judged, WARN-only, numbered last so ids 1-18 stay
                      stable; read-only policy alignment; pre-empts security
                      scanners)
  Budget (16):        Description Length (PASS <=250 chars / WARN 251-400 /
                      FAIL >400; characters not bytes)
  Portability (17-18): Bundle Self-containment, Plugin-root Fallback
                      (WARN-only: runs outside Claude Code's full-plugin install)
