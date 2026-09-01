# Platform-Specific Instructions

## Claude.ai

In Claude.ai, the core workflow is the same (draft -> test -> review -> improve -> repeat), but without subagents some mechanics change:

**Running test cases**: No subagents means no parallel execution. For each test case, read the skill's SKILL.md, then follow its instructions yourself, one at a time. Skip the baseline runs — just use the skill to complete the task as requested.

**Reviewing results**: If you can't open a browser, skip the browser reviewer entirely. Present results directly in the conversation — show the prompt and the output for each test case. If the output is a file, save it and tell the user where it is. Ask for feedback inline.

**Benchmarking**: Skip quantitative benchmarking — it relies on baseline comparisons. Focus on qualitative feedback.

**The iteration loop**: Same as before, just without the browser reviewer in the middle.

**Description optimization**: Requires `claude -p` CLI. Skip it on Claude.ai.

**Blind comparison**: Requires subagents. Skip it.

**Packaging**: `package_skill.py` works anywhere with Python and a filesystem.

**Updating an existing skill**:

- **Preserve the original name.** Note the skill's directory name and `name` frontmatter field — use them unchanged.
- **Copy to a writeable location before editing.** The installed skill path may be read-only. Copy to `/tmp/skill-name/`, edit there, and package from the copy.
- **If packaging manually, stage in `/tmp/` first** — direct writes may fail due to permissions.

## Cowork

- Subagents work, so the main workflow (spawn test cases in parallel, run baselines, grade, etc.) all works. If severe timeout problems, run in series.
- No browser or display — use `--static <output_path>` to write a standalone HTML file. Proffer a link for the user.
- GENERATE THE EVAL VIEWER *BEFORE* evaluating inputs yourself — get results in front of the human ASAP using `generate_review.py` (not custom HTML).
- Feedback works differently: "Submit All Reviews" downloads `feedback.json` as a file.
- Packaging works — `package_skill.py` just needs Python and a filesystem.
- Description optimization (`run_loop.py` / `run_eval.py`) works via `claude -p` subprocess. Save until the skill is fully finished.
- **Updating an existing skill**: Follow the update guidance in the Claude.ai section above.
