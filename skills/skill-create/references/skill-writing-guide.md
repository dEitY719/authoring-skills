# Skill Writing Guide — anatomy, patterns, and style

## Communicating with the User

The skill creator is used by people across a wide range of familiarity with coding jargon — from plumbers opening terminals for the first time to seasoned developers. Pay attention to context cues to understand how to phrase your communication.

- "evaluation" and "benchmark" are borderline, but OK
- for "JSON" and "assertion" you want to see serious cues from the user that they know what those things are before using them without explaining them

It's OK to briefly explain terms if you're in doubt.

## Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── lib/        - Executable helpers for deterministic/repetitive tasks
    ├── references/ - Docs loaded into context as needed
    └── assets/     - Files used in output (templates, icons, fonts)
```

`lib/` is the SSOT location for skill-local executable helpers. Keep `references/`
markdown-only and use `lib/` when the step should be run, not merely read.

## Progressive Disclosure

Skills use a three-level loading system:

1. **Metadata** (name + description) - Always in context (~100 words)
2. **SKILL.md body** - In context whenever skill triggers (<500 lines ideal)
3. **Bundled resources** - As needed (unlimited, scripts can execute without loading)

These word counts are approximate and you can feel free to go longer if needed.

**Key patterns:**

- Keep SKILL.md under 500 lines; if approaching this limit, add hierarchy with pointers
- Reference files clearly from SKILL.md with guidance on when to read them
- For large reference files (>300 lines), include a table of contents
- Prefer executable helpers over prose when the procedure is deterministic, repetitive, or easier to verify in code

## Executable-First Gate

Push a procedure into `lib/*.sh` or `lib/*.py` when it is:

- deterministic file creation, transformation, or scaffold work
- repeated CLI orchestration across steps or test cases
- a multi-step fallback or retry chain
- parsing, validation, normalization, or aggregation logic
- easier to verify by rerunning code than rereading prose

Keep prose for judgment calls, policy rationale, output interpretation, and user communication.
Show direct invocation patterns in SKILL.md, for example:

```bash
bash claude/skills/<name>/lib/<script>.sh
python claude/skills/<name>/lib/<script>.py
```

**Domain organization**: When a skill supports multiple domains/frameworks, organize by variant:

```
cloud-deploy/
├── SKILL.md (workflow + selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

Claude reads only the relevant reference file.

## Principle of Lack of Surprise

Skills must not contain malware, exploit code, or any content that could compromise system security. A skill's contents should not surprise the user in their intent if described. Don't go along with requests to create misleading skills or skills designed to facilitate unauthorized access, data exfiltration, or other malicious activities. Things like a "roleplay as an XYZ" are OK though.

## Writing Patterns

Prefer using the imperative form in instructions.

**Defining output formats** - You can do it like this:

```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

**Examples pattern** - It's useful to include examples:

```markdown
## Commit message format
**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

## Writing Style

Try to explain to the model why things are important in lieu of heavy-handed musty MUSTs. Use theory of mind and try to make the skill general and not super-narrow to specific examples. Start by writing a draft and then look at it with fresh eyes and improve it.

## Frontmatter Fields

- **name**: Skill identifier
- **description**: When to trigger, what it does. This is the primary triggering mechanism — include both what the skill does AND specific contexts for when to use it. All "when to use" info goes here, not in the body. Note: Claude tends to "undertrigger" skills, so make descriptions a little bit "pushy". For instance, instead of "How to build a simple fast dashboard", write "How to build a simple fast dashboard to display internal data. Make sure to use this skill whenever the user mentions dashboards, data visualization, internal metrics, or wants to display any kind of data, even if they don't explicitly ask for a 'dashboard.'"
- **description length**: keep it **≤ 250 characters** (`authoring:skill-check` Check 16
  — WARN 251–400 with a justifying comment, FAIL over 400). Count characters,
  not bytes: Korean trigger phrases are 3 bytes per glyph. Every installed
  skill's description is loaded into the session's `available_skills` listing,
  and Codex/Kimi cap that listing at ~5,440 characters across all skills — a
  long description does not just cost this skill, it crowds out others (#1411).
  This does **not** contradict the "pushy" rule above: keep trigger phrases in
  both Korean and English plus short negative triggers, and move the rest —
  flag semantics to `references/help.md`, behaviour detail to Step sections,
  sister-skill cross-references to the body. "When to use" stays; "how it
  behaves" goes.
- **compatibility**: Required tools, dependencies (optional, rarely needed)

## Test Cases

After writing the skill draft, come up with 2-3 realistic test prompts — the kind of thing a real user would actually say. Share them with the user and ask if they look right or want to add more.

Save test cases to `evals/evals.json`. Don't write assertions yet — just the prompts. You'll draft assertions in the next step while the runs are in progress.

```json
{
    "skill_name": "example-skill",
    "evals": [
        {
            "id": 1,
            "prompt": "User's task prompt",
            "expected_output": "Description of expected result",
            "files": []
        }
    ]
}
```

See `references/schemas.md` for the full schema (including the `assertions` field, which you'll add later).
