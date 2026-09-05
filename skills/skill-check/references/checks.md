# Skill Quality Checks

Sixteen checks, each rated PASS / WARN / FAIL / N/A.

---

## Structure Checks (1–5)

### Check 1: Line Count
PASS ≤ 100 | WARN 101–150 | FAIL > 150
Every line over 100 is a candidate for `references/` extraction.

### Check 2: Progressive Disclosure Structure
PASS — workflow phases only in SKILL.md; detail in `references/`
WARN — mostly workflow but some templates/tables inline
FAIL — large reference content embedded directly in SKILL.md

### Check 3: Frontmatter Validity
Look for: `name` present, `description` present, only known attributes present.
Known attributes: `name`, `description`, `allowed-tools`, `compatibility`,
`metadata`, `user-invocable`, `argument-hint`, `disable-model-invocation`, `license`.
**Naming**: read `references/naming-convention.md` — `category:action` colon
form is the SSOT convention and reports as PASS, not WARN. Folder/name
kebab-vs-colon mismatch is also PASS when folder is the kebab form of the
colon name (e.g., `name: gh:pr` + folder `gh-pr/`).
PASS — valid | WARN — minor issues | FAIL — missing fields or unknown attributes

### Check 4: References Directory Usage
PASS — `references/` exists with focused files, each referenced from SKILL.md
WARN — `references/` exists but not clearly triggered from SKILL.md body
FAIL — SKILL.md > 100 lines AND no `references/` directory

### Check 5: Output Report Defined
PASS — output format with example clearly defined
WARN — output described but vague
FAIL — no output format defined

---

## UX Quality Checks (6–12)

### Check 6: Help Flag Pattern
PASS — `-h`/`--help`/`help` arg → reads `references/help.md` verbatim, then stops. No API calls.
WARN — help exists but inline (not in `references/help.md`) or not verbatim
FAIL — no `-h`/`--help`/`help` support at all

### Check 7: Step Structure
PASS — execution steps numbered (Step 1, Step 2, …) with explicit stop-on-error policy
WARN — steps described but unnumbered, or no stop-on-error policy stated
FAIL — no clear execution flow
N/A — skill is a single read-only lookup (no multi-step execution)

### Check 8: Options Documentation
PASS — all accepted options in a table: Option | Description | Default
WARN — options listed but missing defaults or described in prose only
FAIL — options accepted but not documented
N/A — skill takes no arguments or options

### Check 9: Verdict Output
PASS — final output has explicit `[OK]`/`[FAIL]` verdict + structured key-value pairs
WARN — success/failure indicated but unstructured (plain prose)
FAIL — no explicit verdict in output
N/A — skill is purely informational (no action outcome to report)

### Check 10: Next-action Hint
PASS — success report includes next steps, follow-up commands, or teardown
WARN — partial guidance (mentions what comes next but no concrete commands)
FAIL — output ends without any guidance on what to do next
N/A — skill is terminal (no natural follow-up action exists)

### Check 11: No Emojis
PASS — no emoji glyphs in SKILL.md body or `references/*.md`
FAIL — emoji present AND the skill's allowlist key is NOT in
`references/allowed-emoji-skills.txt`
N/A — the key IS in the allowlist (`[N/A] allowlisted in references/allowed-emoji-skills.txt`)
WARN — allowlist file missing, or an allowlist entry resolves to nothing in the
audited scope (see "Stale entries" below). Degrade rather than block;
authoring:skill-check stays read-only.

Rationale: CLAUDE.md "No emojis anywhere" policy with one exception — the
`ai-metrics` footer's `📊 👤 🤖` glyphs inside `<details>` / `<!-- ai-metrics -->`
blocks (dEitY719/dotfiles#317 F-2, PR #320, #367 wrapper).

Detection: the enforcing gate is
`dEitY719/harness-skills/.github/workflows/skill-check.yml`, so it owns the
definition and this rubric quotes it rather than restating a second range:

```python
def is_emoji(ch):
    cp = ord(ch)
    return 0x1F000 <= cp <= 0x1FAFF or cp == 0xFE0F
```

`U+2600-U+27BF` sits below the range on purpose, so the BMP symbol block —
`✓ ✗ ✅ ❌` and the rest of it — is out of scope for this ban rather than
adjudicated glyph by glyph. `U+FE0F` counts, so a text-presentation glyph plus a
variation selector (`⏸️` = U+23F8 U+FE0F) is caught. The `U+1FAFF` upper bound
keeps plane-2 CJK extension ideographs from reading as emoji. The test is per
character, matching the gate: a ZWJ or skin-tone sequence trips on its base
codepoint, so sequences need no separate rule.

Allowlist key resolution: the key is `<plugin>:<skill>`.

- `<plugin>` — the `name` field of the audited repo's
  `.claude-plugin/plugin.json`. Read it; never infer it from the path. No such
  manifest (a personal skills tree, or a lone skill directory) means there is no
  plugin to qualify with: fall back to the pre-split key — frontmatter `name:`
  as written, colon form converted to hyphens, else the directory basename — and
  say so in the output, because the collision guard below is not in force on
  that path.
- `<skill>` — frontmatter `name:`, falling back to the SKILL.md directory
  basename when absent. In a marketplace repo `name:` must be bare (a colon
  there is a hard CI failure, `skill-check.yml`: `name must be bare, not
  namespaced`), so in practice the two agree — which is exactly why the *key*
  cannot be bare too.

A bare key in this repo's allowlist is invalid and must be reported as one — the
fallback above is a reader for manifest-less trees, not a licence to write bare
keys here. `create` resolves to three different skills — `gh-issue:create`,
`gh-pr:create`, `packaging:create` — so a bare `create` would silently exempt
all three when only two earn it.

Stale entries: an entry whose `<plugin>` matches a repo in the audited scope but
whose `<skill>` directory does not exist there is stale — report it as a WARN
naming the key. Entries for plugins outside the audited scope are out of reach,
not stale: when auditing one repo, do not flag the other repos' entries. Without
this state a full allowlist and an empty one look identical, which is how every
key survived the repo split unnoticed.

Allowlist: `skills/skill-check/references/allowed-emoji-skills.txt` — one key
per line, `#` comments allowed, blank lines ignored. Each entry must carry an
inline rationale comment. This file governs the rubric only; CI exemptions are
separate `allow-emoji-paths` entries in each repo's
`.github/workflows/validate.yml`, and neither implies the other.

FAIL output: list up to 5 matched files+lines and append the guidance
`Remove emoji or add to references/allowed-emoji-skills.txt with rationale`.

---

### Check 12: Executable Procedure Extraction
Audit whether executable, repeatable procedures are still trapped in prose
instead of being extracted into `lib/*.sh` or `lib/*.py`.

| Result | Criteria |
|---|---|
| PASS | deterministic/repetitive procedures are already delegated to helpers, or the skill is genuinely judgment-heavy |
| WARN | at least one candidate helper is still described in prose, but the risk is limited and the remediation is straightforward |
| FAIL | the skill relies on prose for multi-step fallback, repeated command sequences, parsing/validation, aggregation, or reproducible artifact generation |
| N/A | pure reference or policy skill with no executable procedure to extract |

Heuristics to look for:

- multi-step try/retry/fallback instructions written only in prose
- deterministic output generation steps without a helper
- the same command sequence repeated across steps or references
- parsing, validation, normalization, or aggregation logic explained but not coded

WARN/FAIL remediation must name a concrete helper candidate, its expected
inputs/outputs, and a direct call pattern such as
`bash skills/<name>/lib/<script>.sh` or
`python skills/<name>/lib/<script>.py`.

---

## Model Recommendation Check (13)

### Check 13: Model Recommendation Metadata
Read `references/model-recommendation.md` (rubric SSOT) for the full schema,
tier rubric, migration gate, and compatibility policy. This check is
**read-only — it recommends a tier, never switches models or writes files**
(dEitY719/dotfiles#809).

Detect `metadata.model_recommendation` in the SKILL.md frontmatter:

| Result | Criteria |
|---|---|
| PASS | valid `tier` (haiku/sonnet/opus) + `reason` + compatibility (`claude` and `non_claude`) all present |
| WARN | `tier` present but `reason` or compatibility missing — OR metadata absent while the migration gate is open (gate state = `MIGRATION_COMPLETE` in `references/model-recommendation.md`) |
| FAIL | disallowed `tier` value — OR metadata absent after the migration gate closes (gate state = `MIGRATION_COMPLETE` in `references/model-recommendation.md`) |
| N/A | skill explicitly disables model invocation (`disable-model-invocation: true`) |

On WARN-for-absence, suggest the migration command from
`references/model-recommendation.md` Section 3. On FAIL-for-tier, print the
allowed values `haiku | sonnet | opus`.

**Recommended tier (always reported, even when metadata exists):** apply the
Section 2 rubric to the audited skill and report the recommended tier with a
one-line rationale. When metadata is present, note agreement or mismatch with
the declared `tier`.

**Composite skills (F-5 / F-6):** when the SKILL.md body invokes other skills
(`/gh-*`, `gh:*`, `Skill(<name> ...)` patterns), build a 1-depth Sub-skill Model
Plan — read each sub-skill's declared `tier`, mark missing ones `unknown` (WARN),
and report it **separately from this skill's own tier** (see report-template.md).
Recursion is 1-depth by default; `--recursive` opts into deeper traversal.

---

## Security & Policy Alignment Checks (14–15)

These two checks pre-empt findings that external security scanners (e.g. an
org's AgentToolbox scanner) raise against published skills. Both are
**read-only — they flag a policy gap, never edit files** (audit-only invariant).

### Check 14: License Declaration
Cross-check frontmatter `license` against the repo-root `LICENSE` file.

| Result | Criteria |
|---|---|
| PASS | frontmatter declares a `license` field |
| WARN | no `license` in frontmatter BUT a `LICENSE` file exists at the repo root → suggest "add `license: <SPDX>` to frontmatter" (pre-empts scanner `MANIFEST_MISSING_LICENSE`) |
| N/A | repo has no `LICENSE` file (private/experimental skill — nothing to align with) |

Repo root: walk up from the SKILL.md until a `LICENSE`/`LICENSE.md`/`LICENSE.txt`
or a `.git` directory is found; the LICENSE check is relative to that root.
On WARN, recommend a concrete SPDX identifier when the LICENSE is recognizable
(e.g. `license: MIT`), else `license: <SPDX>`.

### Check 15: Capability Declaration Consistency
Scan the skill's executable helpers across both the current `lib/` SSOT and
legacy `scripts/` layouts, plus any `*.sh`/`*.py` shipped beside the SKILL.md,
for network-capability signals and compare against the
`compatibility.network` declaration. 1st-scope is **network only** — the
capability the external scanner actually flags
(`TOOL_ABUSE_UNDECLARED_NETWORK`).

Network signals: imports of `requests` / `httpx` / `urllib` / `http.client` /
`socket` / `aiohttp`, or explicit MCP/HTTP call patterns (e.g. `curl`, `wget`,
`fetch(`, `http(s)://` request construction).

| Result | Criteria |
|---|---|
| PASS | no network signal found, OR network is used AND `compatibility.network` is declared |
| WARN | network signal present BUT no `compatibility.network` declaration → suggest "scripts use the network — declare `compatibility.network: required`" |
| N/A | skill ships no executable scripts (pure-prompt skill — nothing to scan) |

Extension note: filesystem-write and subprocess capabilities follow the same
detect-vs-declare pattern; 1st scope is intentionally network-only because that
is what the scanner flags today. `CROSS_SKILL_SHARED_URL` (multiple skills
sharing one external domain) is **out of scope** — it requires cross-file
analysis, while `authoring:skill-check` audits a single SKILL.md.

---

## Context Budget Check (16)

Skill descriptions are loaded into every session's `available_skills` listing,
so their combined length is a per-session context cost. Codex/Kimi cap that
listing at roughly 2% of context (~5,440 characters across **all** installed
skills) — the reason `scripts/setup-skills-ssot.sh` needs a `.codex-allowlist`
escape hatch. Check 16 keeps one description inside its share of that budget.
Read-only — it reports the overage, never edits the file (audit-only invariant).

### Check 16: Description Length
Count the frontmatter `description` in **characters, not bytes** — Korean
trigger phrases are 3 bytes per glyph, so byte counting over-reports by ~3x and
would fail every bilingual description. Fold a multi-line (`>-`) description to
one whitespace-normalised line first, stopping at the next top-level key so
`metadata` / `compatibility` / `allowed-tools` are never counted as description
text.

| Result | Criteria |
|---|---|
| PASS | <= 250 characters |
| WARN | 251–400 characters — allowed, but the SKILL.md must carry a comment justifying the exception |
| FAIL | > 400 characters — move the detail out (see below) |
| N/A | no `description` in frontmatter (Check 3 already reports that as FAIL) |

**Keep in the description** — it exists to make the skill trigger:
- trigger phrases in both Korean and English
- negative triggers (`Do NOT use for X — use Y instead`), kept short

**Move it out** — this is what pushes a description past 400:
- option/flag semantics → `references/help.md` / `references/options.md`
  (Check 8 already requires an options table there)
- behaviour detail (`Idempotent`, `auto-detected`, warning conditions) →
  SKILL.md Step sections
- sister-skill cross-references (`Sister skills: ...`) → a Related Skills line
  in the SKILL.md body

Executable mirror: `tests/bats/skills/_fixtures/skill_description_length.sh`
(`skill_desc_extract` / `skill_desc_length` / `skill_desc_verdict`), pinned by
`tests/bats/skills/skill_check_description_length.bats`. Keep the thresholds
byte-identical between that fixture and the table above.

**This check measures length only.** A description can pass Check 16 and still
have stopped triggering — that is the failure mode dEitY719/dotfiles#1411's
diet risked and dEitY719/dotfiles#1417 had to measure separately. Trigger
accuracy is out of scope for a read-only audit (it costs API budget per query),
so it lives in a manual
harness instead: `references/trigger-eval-procedure.md` →
`claude/tools/run-trigger-eval.sh`. Run it when a description is shrunk, when a
skill is renamed, or when a competing pair's boundary wording changes.
