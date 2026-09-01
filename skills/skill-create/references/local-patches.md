# Local patches to the vendored skill-create

`claude/skills/skill-create/` is a **copy** of the Claude Code marketplace
`skill-creator` plugin, taken deliberately so it survives plugin updates
(`b13f6686`, 2026-04-02). The original still ships on this machine at
`~/.claude-shared/plugins/marketplaces/anthropic-agent-skills/skills/skill-creator/`,
which is what a re-import would diff against — before #1412 the only
divergence in `scripts/` was ruff reflow. The copy is the SSOT: nothing re-syncs it from the
marketplace, and it has already diverged (Korean SKILL.md, the `authoring:skill-create`
name, `metadata.model_recommendation`, the Phase 8 quality gate, a
progressive-disclosure `references/` split).

## Upstream path — decided (issue #1412)

The fix for #1412 lands **here, permanently**. There is no vendor manifest,
no update job, and no fork to send a PR against — the marketplace plugin is
distributed, not developed, in this repo. Re-importing from the marketplace is
not a workflow anyone runs; if someone ever does, this file is the list of what
to re-apply, and each patch site carries a `LOCAL PATCH (dotfiles #1412)`
comment so a diff makes the answer obvious.

Reporting the same defect to Anthropic is optional and out of scope for #1412 —
it would need the marketplace plugin's own issue tracker, which this tree does
not record.

## Registry

| Patch | File | Why |
|---|---|---|
| #1412 F-1 | `scripts/run_eval.py` — `TriggerDetector` / `detect_trigger` | Upstream settled the whole query at the **first** tool block: a non-`Skill`/`Read` block returned False outright, and `content_block_stop` returned the verdict then and there. With the evaluated skill already installed, the model answers with the real skill first and the uuid probe never got looked at — every real trigger scored `trigger_rate 0.0`. Now every block is inspected and a negative is only settled at end of stream. |
| #1412 F-2 | `scripts/run_eval.py` — `_outcome`, `_read_stderr`, `run_single_query`, `run_eval`, verbose report | Upstream sent the subprocess' stderr to `DEVNULL`, so auth expiry, the nesting guard and timeouts all reported the same `0.0` as a description that simply never fires. Each run now carries an explicit `error`; errored runs leave the trigger-rate denominator, a query with nothing usable can never be scored a pass, and `--verbose` prints `[ERROR]` plus the captured stderr. |
| #1412 F-2b | `scripts/utils.py` — `usable_runs()`, used by `run_loop.py`, `generate_report.py`, `improve_description.py` | `run_eval()` counts `triggers` over the runs that executed, but `runs` stayed the raw attempt count, so every consumer dividing one by the other re-implemented the bug one layer up: an all-errored negative query scored as fully correct in the HTML report, and an all-errored query reached the improvement model labelled "triggered 0/3 times — FAILED TO TRIGGER". One helper is now the single denominator. |
| #1412 F-3 | `scripts/run_eval.py` — `find_shadowing_skills` + the `main()` warning | The `CLAUDE_CONFIG_DIR` isolation workaround is easy to forget. An installed skill of the same name is now named on stderr instead of quietly making the run noisier. |
| #1432 | `scripts/__init__.py` — **deleted** | The (empty) file made this a *regular* package, which outranks the repo-root `scripts/` **namespace** package. `tests/integration/test_skill_create_run_eval.py` must keep this directory on `sys.path` for the whole session (pickling, see its module comment), so from #1429 onward every `scripts.maintenance.*` import in the suite died at collection time — run serially (`-n 0`) that cost all 1350 tests, and the default `-n auto` path exited 1 as well; what parallel collection hid was the *scale*, not the defect (#1448). With the file gone both directories are namespace *portions* and their `scripts.*` trees merge. `python -m scripts.run_loop` from the skill dir is unaffected. |

A deletion cannot carry an in-file `LOCAL PATCH` comment, so a re-import from
the marketplace must remember to delete `scripts/__init__.py` again — the guard
in `tests/integration/test_collection_integrity.py` goes red if it returns.

## Regression guards

`tests/integration/test_skill_create_run_eval.py` pins all of them. The stream
decision logic is a pure function over stream-json lines, so the cases that
used to be unreachable (probe behind a real skill call, probe behind a `Bash`
call, probe in a later `assistant` content item) are cheap to assert.

## Closed gap (#1428)

F-2's `[ERROR]` labelling and F-3's shadowing warning used to be wired into
`run_eval.py`'s `main()` only. `run_loop.py` calls `run_eval()` directly, so
the documented optimization entry point (`python -m scripts.run_loop`, see
`references/description-optimization.md`) printed neither, and its per-query
line still divided `triggers` by the raw attempt count.

Both call sites now share `utils.format_result_lines()` — the `[ERROR]` rule,
the `usable_runs()` denominator and the stderr excerpt are derived in one
place, since re-deriving them per call site is what opened the gap. The
warning moved to `run_eval.warn_shadowing_skills()`, which `run_loop()` emits
once per run before the first iteration.
