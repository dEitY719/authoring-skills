# Description Optimization — improving skill triggering accuracy

The description field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes a skill. After creating or improving a skill, offer to optimize the description for better triggering accuracy.

## Step 1: Generate trigger eval queries

Create 20 eval queries — a mix of should-trigger and should-not-trigger. Save as JSON:

```json
[
    { "query": "the user prompt", "should_trigger": true },
    { "query": "another prompt", "should_trigger": false }
]
```

The queries must be realistic — concrete, specific, with detail like file paths, personal context, column names, company names, URLs. Some might be lowercase, contain abbreviations, typos, or casual speech. Use a mix of lengths, focus on edge cases.

Bad: `"Format this data"`, `"Extract text from PDF"`, `"Create a chart"`

Good: `"ok so my boss just sent me this xlsx file (its in my downloads, called something like 'Q4 sales final FINAL v2.xlsx') and she wants me to add a column that shows the profit margin as a percentage. The revenue is in column C and costs are in column D i think"`

For **should-trigger** queries (8-10): different phrasings of the same intent — some formal, some casual. Include cases where the user doesn't explicitly name the skill but clearly needs it. Include uncommon use cases and cases where this skill competes with another but should win.

For **should-not-trigger** queries (8-10): near-misses that share keywords but need something different. Think adjacent domains, ambiguous phrasing where a naive keyword match would trigger but shouldn't. Don't make them obviously irrelevant.

## Step 2: Review with user

Present the eval set using the HTML template:

1. Read the template from `assets/eval_review.html`
2. Replace placeholders:
    - `__EVAL_DATA_PLACEHOLDER__` → the JSON array (no quotes — it's a JS variable assignment)
    - `__SKILL_NAME_PLACEHOLDER__` → the skill's name
    - `__SKILL_DESCRIPTION_PLACEHOLDER__` → the skill's current description
3. Write to `/tmp/eval_review_<skill-name>.html` and open it
4. The user edits queries, toggles should-trigger, adds/removes entries, clicks "Export Eval Set"
5. File downloads to `~/Downloads/eval_set.json`

## Step 3: Run the optimization loop

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id-powering-this-session> \
  --max-iterations 5 \
  --verbose
```

Use the model ID from your system prompt so the triggering test matches what the user actually experiences. While it runs, periodically tail the output to give the user updates.

The loop splits the eval set into 60% train and 40% held-out test, evaluates the current description (running each query 3 times), then calls Claude to propose improvements based on what failed. It re-evaluates each new description on both train and test, iterating up to 5 times. It selects `best_description` by test score to avoid overfitting.

## How skill triggering works

Skills appear in Claude's `available_skills` list with their name + description, and Claude decides whether to consult a skill based on that description. Claude only consults skills for tasks it can't easily handle on its own — simple, one-step queries may not trigger a skill even if the description matches perfectly. Complex, multi-step, or specialized queries reliably trigger skills when the description matches.

This means eval queries should be substantive enough that Claude would actually benefit from consulting a skill.

## Reading the harness output

`run_eval.py` distinguishes three outcomes per query, not two:

- `[PASS]` / `[FAIL]` — the description did or did not trigger.
- `[ERROR]` — `claude -p` never ran to completion (auth expiry, the nesting
  guard, a timeout). The captured stderr is printed under the query, and those
  runs are held out of the trigger rate. A query with no usable run left can
  never be scored a pass, so a dead harness reads as a dead harness instead of
  a tidy row of zeros.

A `Warning: installed skill '<name>' shadows this eval` line means a skill of
the same name is visible to the model, which will often answer with the real
skill rather than the temporary probe. The score stays correct — the probe is
counted wherever in the stream it appears — but an isolated
`CLAUDE_CONFIG_DIR` still gives the cleanest signal.

These three behaviors are local fixes to the vendored copy; see
`references/local-patches.md`.

## Step 4: Apply the result

Take `best_description` from the JSON output and update the skill's SKILL.md frontmatter. Show the user before/after and report the scores.
