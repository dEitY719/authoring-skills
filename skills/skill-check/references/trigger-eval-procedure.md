# Trigger-accuracy eval — reproducible procedure (dEitY719/dotfiles#1417)

Check 16 measures a `description`'s **length**. It cannot tell a short
description from a short-and-broken one. This file is the missing half: how to
measure whether a description still gets its skill invoked.

Harness: `claude/tools/run-trigger-eval.sh` (manual, spends API budget, not
wired into `mise run test`).

## The contract

For each skill, over its own `evals/trigger-eval.json` query set:

```
after_score >= before_score - 5 percentage points
```

`before` = the `description` as of the dEitY719/dotfiles#1411 parent
(`bd91d5dc^`), `after` = the working tree. A skill that misses the bar is
reverted to a WARN-band description (251–400 chars) with a justifying comment,
per dEitY719/dotfiles#1411 decision D-1 — it is never re-shrunk to chase the
number.

### Restoring a below-contract description

Which half of the score dropped tells you what to put back — they are two
different repairs, measured separately on the pair dEitY719/dotfiles#1417 had
to fix:

| symptom | what was deleted | what restores it |
|---|---|---|
| **reject** fell, recall held | the boundary — `Do NOT use for X — use Y instead`, or a `Sister skill of Y (…)` line | the boundary sentence alone |
| **recall** fell | the positive discriminator — the *when do I use this* condition (`no running app`, `dirty worktree`) | that condition; a boundary alone does not help, and can cost more recall |

`gh-verify:live` lost only the boundary; restoring it went 65% → 90%.
`gh-verify:merged` lost both — boundary alone left it at 75% with recall
5/10, and only restoring the discriminator too returned it to 90%.

Put the justification in a YAML comment **above** `description:`. The Check 16
extractor (`tests/bats/skills/_fixtures/skill_description_length.sh`) starts at
the `description:` key, so a comment there sits next to the value it explains
without counting toward the measured length. Re-measure after every rewrite —
a reverted wording that has not been measured is a guess.

## Query sets

One file per skill at `skills/<skill>/evals/trigger-eval.json`, a flat
array of exactly 20 objects, 10 `should_trigger: true` and 10 false:

```json
[
  { "query": "실제 사용자가 칠 법한 구체적 발화", "should_trigger": true },
  { "query": "키워드는 겹치지만 다른 스킬이 맞는 발화", "should_trigger": false }
]
```

Authoring rules that keep the measurement honest:

- **Write from the SKILL.md body, never from either description.** A query
  lifted from the old description rigs the comparison toward `before`; one
  lifted from the new description rigs it toward `after`.
- **Natural language over slash literals.** dEitY719/dotfiles#1410 renames
  every namespace (`gh:issue-create` → `gh-issue:create`), which invalidates
  slash-literal queries. Natural-language queries survive the rename and are
  the fixed points that let dEitY719/dotfiles#1410 re-use these sets to prove
  the rename did not undo the diet's gains. Any query that does carry a slash
  literal is tagged `"note": "slash-literal: update if the skill is renamed
  (dEitY719/dotfiles#1410)"`.
- **Competing pairs cross-reference each other.** For a pair like
  `authoring:skill-check` ↔ `authoring:sh-check`, at least 4 of each side's false-queries are the
  other side's true-queries, tagged `"note": "cross-pair: ..."`. A misfire is
  then a measured failure, not an untested assumption.
- The file lives under the skill directory so it travels with the skill when
  skills are split into marketplaces (dEitY719/dotfiles#1410).

### One harness constraint that shapes true-queries

A query only counts as triggered when the probe's own uuid command is the thing
Claude invokes. So a `should_trigger: true` query must be phrased so that
consulting the skill is the natural *opening* move — ask for the workflow, not
for a lookup. Queries that send Claude grepping or shelling out first muddy the
measurement. This does not bind false-queries.

Before `b41dae08` this was absolute: the query was settled at the first tool
block, so anything other than `Skill`/`Read` scored a miss outright. That
early return is gone — every block is now inspected — but phrasing still moves
the number, so the guidance stands.

Worked example from dEitY719/dotfiles#1417: bare slash-command queries like
`/devx-pr-verify-merged 1388 --matrix full` scored **0/3 in every arm** — and
`gh-verify:live`, whose description *does* advertise its hyphen alias, scored
0/3 on the equivalent query too. The built-in control shows the alias is not
the variable; the phrasing is.

## Probe twin-shadowing — the one failure mode, four causes

`run_eval.py` registers the description under test as a uuid-named temp slash
command and asks whether `claude -p <query>` calls **that** name. The
measurement is valid only while exactly ONE such twin is visible to the probe
session — any second copy of the same skill can win the call instead, and the
probe's own uuid then never appears. It fails silently and reads as "the
description is bad".

Four separate things create a twin. `run-trigger-eval.sh` suppresses all four:

| # | Twin source | Isolation | Evidence |
|---|---|---|---|
| 1 | **Installed.** dotfiles exposes all 71 skills through `~/.claude*/skills/` | `CLAUDE_CONFIG_DIR` → throwaway dir holding only a copy of `.credentials.json` | dEitY719/dotfiles#1412: 154 exposed slash commands → `trigger_rate 0.0`; 50 exposed → `1.0`, nothing else changed |
| 2 | **Leftover.** A probe file from an earlier run is still in `.claude/commands/` | Every job gets a freshly created probe project, removed on exit | dEitY719/dotfiles#1412 |
| 3 | **Concurrent.** `run_eval --num-workers N` writes N uuid probes into ONE shared `.claude/commands/`, so N near-identical twins are visible at once; each worker only recognises its own uuid | `run_eval` is always invoked with `--num-workers 1`; parallelism moves up to `--jobs`, one whole (skill, arm) measurement per private config dir + probe project | dEitY719/dotfiles#1417, identical `authoring:sh-check` query — before `b41dae08`: `--num-workers 3` → **0/3 FAIL** vs `1` → **3/3 PASS**; re-measured after it: **1/3 FAIL** vs **3/3 PASS** |
| 4 | **Real checkout.** Without `PYTHONPATH`, `run_eval` only imports when cwd is `skill-create/`, and `find_project_root()` then writes probes into `~/dotfiles/.claude/commands/` | `PYTHONPATH` carries the `skill-create` dir; cwd is the probe project | cause 2, aimed at the live checkout |

### What `b41dae08` (dEitY719/dotfiles#1412) changed, and what it did not

dEitY719/dotfiles#1412's fixes have since landed on `main`. `run_eval.py` no
longer settles the whole query at the first tool block — `TriggerDetector`
inspects every block and only settles a negative at end of stream — and errored
runs now leave the trigger-rate denominator instead of scoring as "did not
fire". Registry: `skills/skill-create/references/local-patches.md`.

That removes the *severity* of causes 1–2 (a real trigger behind an installed
twin now scores correctly) but not the need for isolation, and re-measurement
shows **cause 3 still breaks the run**: with the fix in place, three concurrent
workers still scored 1/3 against 3/3 serial. The `--num-workers 1` pin stays.

Do not treat any isolation here as obsolete without re-measuring it. The two
pins in this harness were re-verified against the fixed runner; that is the only
reason their status is stated with confidence.

Cause 3 is the trap worth restating: it is *created by the harness itself*, so
"just add workers to make it faster" silently corrupts the run.

**Reading `recall 0/10, reject 10/10`.** That pattern — a whole-set score near
50%, every query scored as not-triggered, which flatters the reject class into a
perfect run — is why the harness prints recall and reject separately instead of
one number. But it is a *suspicion*, not a diagnosis: a description that
genuinely does not describe the task produces exactly the same shape (measured
below, the unrelated-domain control scored `recall 0/10, reject 10/10`). To tell
the two apart, re-run one arm you know should trigger. If that arm also reports
zero recall, it is shadowing; if it recovers, the zero was real.

Every temp dir, copied credentials included, is removed via
`trap ... EXIT INT TERM`. That is the acceptance criterion "임시 설정 디렉토리와
복사한 credentials 가 삭제됐다", enforced structurally rather than by
remembering.

## Why `--model sonnet` is the default

The contract is a **delta between two descriptions**, so the model only has to
be held *constant* across the two arms, not maximised. `sonnet` is the default
because it is roughly an order of magnitude cheaper per query at equal
diagnostic value. Override with `--model`, but use one value for both arms or
the numbers are meaningless.

**Historical note — this used to be a correctness requirement, and no longer
is.** Before `b41dae08`, `run_eval.py` settled the query at the first tool
block, which it could not read for every model. Measured then on one identical
`authoring:sh-check` query: `opus` **0/2 FAIL**, `sonnet` **1/1 PASS** — the `Skill` call
happened under opus, but the detector missed it. Re-measured after the fix, on
the same query: `opus` **3/3 PASS**, `sonnet` **3/3 PASS**. The model-dependence
is gone; only the cost argument remains.

That correction is itself the lesson: a pin justified by a defect must be
re-measured when the defect is fixed, or the justification quietly becomes
folklore.

## Measurement provenance

Numbers recorded in `docs/guide/learnings/skill-description-trigger-eval.md`
were taken **before** `b41dae08`. They stay internally valid — both arms ran on
the identical runner, and the contract is a delta — but they are **not
reproducible against today's `run_eval.py`**, which scores strictly more
triggers. Re-measure before comparing new numbers against that table, and state
which runner a figure came from whenever you add one.

## Deviation from the train/test split

`description-optimization.md` scores on a 40% held-out test slice because
`run_loop.py` *selects* a description and would otherwise overfit. This harness
selects nothing — it measures two fixed descriptions — so there is no
overfitting risk, and it scores on all 20 queries. More data, same contract.

## Running it

```bash
# both arms, all defaults (sonnet, 3 runs/query, 6 concurrent jobs)
claude/tools/run-trigger-eval.sh gh-commit gh-pr

# cheap smoke of just the current description
claude/tools/run-trigger-eval.sh --arm after --runs 1 sh-check

# negative control: feed a deliberately gutted description
claude/tools/run-trigger-eval.sh --description "$(cat variant.txt)" sh-check
```

Exit status is `1` when any skill is below contract. Per-query detail lands in
`<out-dir>/<skill>.<arm>.json`; the table is derived from
`<out-dir>/summary.tsv`.

Budget: one `claude -p` per query per run per arm — a default two-arm run of one
skill is 120 probes and takes roughly 5 minutes. `--jobs` scales wall-clock;
`--num-workers` is not exposed on purpose (twin source 3 above).

### Reading the noise floor

Each set is 20 queries, so **one query flipping moves the score by 5%p** — the
same size as the contract margin. Measured on `sh-check`, same description and
same set, three times: 70% / 85% / 80%. **Repeat-measurement spread is 15%p,
three times the margin.**

So treat a delta inside ±5%p as "no detected change", never as a measured
improvement or regression, and do not act on a single measurement of a single
skill. A delta worth acting on has all three of:

1. magnitude clearly above the spread,
2. an identifiable half — recall or reject — that moved, and
3. a sentence in the description you can point at as the cause.

Raise `--runs` to tighten the per-query majority vote when a skill lands on the
boundary and the answer matters.

## The negative control — validating the instrument

A passing eval proves nothing unless the eval set can also fail. Run a third arm
for at least one sample skill with a deliberately broken description and confirm
the score drops. Measured on `devx-mise-migrate`'s 10 should-trigger queries
(dEitY719/dotfiles#1417):

| description under test | recall | score |
|---|---|---|
| real, post-#1411 | 7/10 | 85% |
| **keywords stripped, meaning kept** | 7/10 | 80% |
| **unrelated domain** (a bookmark-filing description) | **0/10** | 50% |

The middle row is the useful one. That variant removed every literal trigger —
`mise`, `uv`, `venv`, `pip`, `Python`, both slash literals and both Korean
trigger phrases — and left only a paraphrase: "toolchain versions, environment
variables, and command entry points in a single declarative manifest at the
repository root". Triggering did not move.

So **matching is semantic, not lexical.** Two consequences:

1. The instrument is validated by the third row, not the second. A negative
   control has to break the *meaning*; deleting keywords while paraphrasing the
   same job is not a control at all. If your control does not move the score,
   check that it actually stopped describing the task before blaming the query
   set.
2. This is the mechanism that made dEitY719/dotfiles#1411's diet safe. What the
   diet deleted was mostly quoted trigger phrases and option prose; what it
   kept was the sentence that says what the skill does. That sentence is what
   triggering runs on.

## Results

Measured runs are recorded in
`docs/guide/learnings/skill-description-trigger-eval.md`.
