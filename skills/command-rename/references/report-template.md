# authoring:command-rename — Report (F-9)

Print exactly one report block. No preamble, no design recap (that lives in
the issue body).

## Success — no rule gap

```
[OK] refactor issue #<N> created: <url>
  family: <command-family>  ->  convention: <desired-convention>
  renamed: <count> names   dropped: <count>   git-family excluded: gb, gwt
Next: /gh-flow:issue <N>
```

## Success — with rule gap (docs issue + cross-link)

```
[OK] refactor issue #<N> created: <url>
[OK] docs issue #<M> created: <url>   (rule gap: <convention> not in SSOT)
  cross-linked: #<N> <-> #<M>
Next: /gh-flow:issue <N>
```

## Failure

```
[FAIL] <what failed> (e.g. gh-issue:create returned non-zero / remote not found)
<the error line>
```

## Rules

- Always include every created issue's number **and** URL.
- Always end the success path with a `Next:` hint pointing at
  `/gh-flow:issue <refactor-issue-number>` (the refactor issue, not the docs
  issue — the docs issue is authored separately).
- Exactly one `[OK]`/`[FAIL]` verdict per created issue; a single `[FAIL]`
  block on precondition failure.
