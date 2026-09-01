# Improvement Philosophy — how to iterate on a skill

This is the heart of the loop. You've run the test cases, the user has reviewed the results, and now you need to make the skill better based on their feedback.

## How to think about improvements

1. **Generalize from the feedback.** We're trying to create skills that can be used a million times across many different prompts. You and the user are iterating on only a few examples because it helps move faster. But if the skill works only for those examples, it's useless. Rather than put in fiddly overfitty changes or oppressively constrictive MUSTs, if there's some stubborn issue, try branching out with different metaphors or recommending different patterns. It's relatively cheap to try.

2. **Keep the prompt lean.** Remove things that aren't pulling their weight. Read the transcripts, not just the final outputs — if the skill is making the model waste time on unproductive things, try getting rid of those parts and see what happens.

3. **Explain the why.** Try hard to explain the **why** behind everything you're asking the model to do. Today's LLMs are *smart*. They have good theory of mind and when given a good harness can go beyond rote instructions. Even if the feedback from the user is terse or frustrated, try to actually understand the task and transmit this understanding into the instructions. If you find yourself writing ALWAYS or NEVER in all caps, that's a yellow flag — reframe and explain the reasoning instead. That's a more humane, powerful, and effective approach.

4. **Look for repeated work across test cases.** Read the transcripts and notice if the subagents all independently wrote similar helper scripts, retried the same manual sequence, or used the same A-then-B fallback. If all 3 test cases resulted in a `create_docx.py`, a `build_chart.py`, or the same recovery chain, that's a strong signal the skill should bundle that logic. Write it once, put it in `lib/`, and tell the skill to call it directly.

This task is important and your thinking time is not the blocker; take your time and really mull things over. Write a draft revision then look at it with fresh eyes and improve it.

## The iteration loop

After improving the skill:

1. Apply your improvements to the skill
2. Rerun all test cases into a new `iteration-<N+1>/` directory, including baseline runs. If creating a new skill, the baseline is always `without_skill`. If improving an existing skill, use your judgment on baseline: the original version or the previous iteration.
3. Launch the reviewer with `--previous-workspace` pointing at the previous iteration
4. Wait for the user to review and tell you they're done
5. Read the new feedback, improve again, repeat

Keep going until:

- The user says they're happy
- The feedback is all empty (everything looks good)
- You're not making meaningful progress

## Advanced: Blind comparison

For more rigorous comparison between two versions of a skill, there's a blind comparison system. Read `agents/comparator.md` and `agents/analyzer.md` for the details. The basic idea is: give two outputs to an independent agent without telling it which is which, and let it judge quality. Then analyze why the winner won.

This is optional, requires subagents, and most users won't need it. The human review loop is usually sufficient.
