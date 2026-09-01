# Eval Pipeline — running, grading, and reviewing test cases

This section is one continuous sequence — don't stop partway through. Do NOT use `/skill-test` or any other testing skill.

Put results in `<skill-name>-workspace/` as a sibling to the skill directory. Within the workspace, organize results by iteration (`iteration-1/`, `iteration-2/`, etc.) and within that, each test case gets a directory (`eval-0/`, `eval-1/`, etc.). Create directories as you go.

## Step 1: Spawn all runs (with-skill AND baseline) in the same turn

For each test case, spawn two subagents in the same turn — one with the skill, one without. Launch everything at once so it all finishes around the same time.

**With-skill run:**

```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
- Outputs to save: <what the user cares about — e.g., "the .docx file", "the final CSV">
```

**Baseline run** (same prompt, but the baseline depends on context):

- **Creating a new skill**: no skill at all. Same prompt, no skill path, save to `without_skill/outputs/`.
- **Improving an existing skill**: the old version. Before editing, snapshot the skill (`cp -r <skill-path> <workspace>/skill-snapshot/`), then point the baseline subagent at the snapshot. Save to `old_skill/outputs/`.

Write an `eval_metadata.json` for each test case (assertions can be empty for now). Give each eval a descriptive name based on what it's testing — not just "eval-0".

```json
{
    "eval_id": 0,
    "eval_name": "descriptive-name-here",
    "prompt": "The user's task prompt",
    "assertions": []
}
```

## Step 2: While runs are in progress, draft assertions

Don't just wait — draft quantitative assertions for each test case and explain them to the user. Good assertions are objectively verifiable and have descriptive names that read clearly in the benchmark viewer.

Subjective skills (writing style, design quality) are better evaluated qualitatively — don't force assertions onto things that need human judgment.

Update the `eval_metadata.json` files and `evals/evals.json` with the assertions once drafted.

## Step 3: As runs complete, capture timing data

When each subagent task completes, you receive a notification containing `total_tokens` and `duration_ms`. Save this data immediately to `timing.json` in the run directory:

```json
{
    "total_tokens": 84852,
    "duration_ms": 23332,
    "total_duration_seconds": 23.3
}
```

This is the only opportunity to capture this data — process each notification as it arrives.

## Step 4: Grade, aggregate, and launch the viewer

Once all runs are done:

1. **Grade each run** — spawn a grader subagent (or grade inline) that reads `agents/grader.md` and evaluates each assertion against the outputs. Save results to `grading.json` in each run directory. The grading.json expectations array must use the fields `text`, `passed`, and `evidence` (not `name`/`met`/`details` or other variants) — the viewer depends on these exact field names. For assertions that can be checked programmatically, write and run a script.

2. **Aggregate into benchmark** — run the aggregation script:

    ```bash
    python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
    ```

    This produces `benchmark.json` and `benchmark.md` with pass_rate, time, and tokens for each configuration. If generating benchmark.json manually, see `references/schemas.md` for the exact schema. Put each with_skill version before its baseline counterpart.

3. **Do an analyst pass** — read the benchmark data and surface patterns the aggregate stats might hide. See `agents/analyzer.md` for what to look for — non-discriminating assertions, high-variance evals, and time/token tradeoffs.

4. **Launch the viewer** with both qualitative outputs and quantitative data:

    ```bash
    nohup python <skill-create-path>/eval-viewer/generate_review.py \
      <workspace>/iteration-N \
      --skill-name "my-skill" \
      --benchmark <workspace>/iteration-N/benchmark.json \
      > /dev/null 2>&1 &
    VIEWER_PID=$!
    ```

    For iteration 2+, also pass `--previous-workspace <workspace>/iteration-<N-1>`.

    **Cowork / headless environments:** Use `--static <output_path>` to write a standalone HTML file instead of starting a server.

5. **Tell the user** the results are in their browser. Two tabs: "Outputs" for test case review and feedback, "Benchmark" for quantitative comparison.

## What the user sees in the viewer

The "Outputs" tab shows one test case at a time:

- **Prompt**: the task that was given
- **Output**: the files the skill produced, rendered inline where possible
- **Previous Output** (iteration 2+): collapsed section showing last iteration's output
- **Formal Grades** (if grading was run): collapsed section showing assertion pass/fail
- **Feedback**: a textbox that auto-saves as they type
- **Previous Feedback** (iteration 2+): their comments from last time

The "Benchmark" tab shows stats summary: pass rates, timing, and token usage for each configuration.

Navigation is via prev/next buttons or arrow keys. When done, "Submit All Reviews" saves all feedback to `feedback.json`.

## Step 5: Read the feedback

When the user tells you they're done, read `feedback.json`:

```json
{
    "reviews": [
        {"run_id": "eval-0-with_skill", "feedback": "the chart is missing axis labels", "timestamp": "..."},
        {"run_id": "eval-1-with_skill", "feedback": "", "timestamp": "..."},
        {"run_id": "eval-2-with_skill", "feedback": "perfect, love this", "timestamp": "..."}
    ],
    "status": "complete"
}
```

Empty feedback means the user thought it was fine. Focus improvements on test cases where the user had specific complaints.

Kill the viewer server when done: `kill $VIEWER_PID 2>/dev/null`
