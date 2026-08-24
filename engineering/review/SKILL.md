---
name: review
description: >-
  The code-review method. Scan a target diff for correctness bugs and for reuse
  / simplification / efficiency / altitude cleanups, verify each finding before
  reporting, and rank most-severe first with file:line and a concrete failure
  scenario. Model-invoked discipline composed by `codebase-review` and
  `pr-review`; not run directly.
user-invocable: false
---

# review

Find what's actually wrong, then prove it before you say it. Two lenses, always:
**correctness** (bugs that produce wrong output, crash, corrupt, or regress) and
**cleanup** (reuse an existing helper, simplify, drop dead work, fix altitude).
The invoking front door sets the target and the tier.

1. **Read the change in context**: the diff plus enough surrounding code to
   know what the change is _for_. A finding you can't ground in the code is
   noise. For the cleanup lens, sweep the diff against the `design`
   discipline's smell baseline (its `smells.md`) under its binding rules:
   labelled judgment calls, repo-documented standards override.
2. **Verify before reporting.** For each candidate, construct the concrete
   inputs/state → wrong result. If you can't, it's a hunch, not a finding; drop
   it or mark it explicitly uncertain. Default to skepticism; a plausible but
   unproven finding is worse than silence.
3. **Rank and report**: most-severe first, each with `file:line`, a one-line
   defect statement, and the failure scenario. Keep correctness and cleanup
   separate. Scale breadth to the requested effort: low → few high-confidence;
   high → wider coverage that may include uncertain calls (marked as such).

No artifact. Findings return to the front door that invoked you.
