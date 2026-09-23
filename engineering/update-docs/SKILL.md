---
name: update-docs
description: >-
  Reconcile docs with the implementation after an increment lands: fix docs that
  describe behavior the code no longer has. Runs as @linn. Use on "update the
  docs", "reconcile the docs", after `implement` changes behavior.
---

# update-docs

Docs drift from code; this closes the gap against what the code actually does
now. Run it as **@linn** (Opus 5.5 medium holds the tier), the docs steward.

1. **Find the drift.** From the increment's diff (resolve through `HEAD.md`),
   locate docs describing behavior the code no longer has: READMEs, module docs,
   API references, comments that lie.
2. **Fix against the code.** Correct each to the current behavior; point at the
   source of truth rather than duplicating it. Don't write docs for behavior that
   doesn't exist.
3. **Tidy in passing.** Flag vault hygiene (missing ids/times, stale `HEAD.md`)
   per `~/Dev/notes/_saving.md`; harvest a durable lesson via the valve if one
   sits unharvested.

## Filing

Docs land in-repo (git via @tux). Update `HEAD.md` if the increment's doc state
changed. No vault artifact. The docs are the deliverable.
