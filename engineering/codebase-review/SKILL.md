---
name: codebase-review
description: >-
  Review the working diff in-repo — compose the `review` discipline against
  uncommitted / branch changes for correctness bugs and cleanups. Qualifies to
  dodge the built-in /code-review. Use on "review my changes", "review the diff
  before I push".
model: claude-opus-5
effort: high
---

# codebase-review

A thin front door: point the `review` discipline at the local working diff.

1. **Resolve the target** — the uncommitted working tree, or the current branch
   vs its merge-base with the default branch. State which before reviewing.
2. **Compose `review`** — run the `review` discipline on that diff at Opus 5
   high, reading surrounding code to ground findings.
3. **Return findings** — most-severe first; offer to apply the cleanups (a human
   call) rather than editing silently.

No artifact — the findings are the deliverable.
