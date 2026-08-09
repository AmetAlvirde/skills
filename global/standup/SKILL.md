---
name: standup
description: >-
  Log-in briefing. Bare, it spans every project — where each stands and where
  the next move has most leverage — refreshing the rolling hq/SITREP.md and
  opening today's daylog. Given a project or target, it briefs only that.
disable-model-invocation: true
---

# standup

The log-in ritual: one read that tells you where to spend the day. Spawn
**@radar** to produce it per its charter (leverage ranking, pointer resolution,
the linn boundary).

**Brief at the smallest scope that answers what was asked** — the same contract
`/enn` runs:

- **An argument naming a project or target** (`numisma`, a handoff, a repo):
  that IS the scope. Read that project's `HEAD.md` and its recent artifacts and
  nothing else — no other project's HEAD, not to rank against them, not to
  "confirm" a scope you were handed.
- **Bare `/standup`**: only then the cross-project read.

Radar:

1. **Reads the field** — every `HEAD.md` in scope plus its recent artifacts, per
   `~/Dev/notes/_saving.md`.
2. **Refreshes `hq/SITREP.md`** — the rolling briefing (`artifact: sitrep`,
   undated, always-current): per-project Ball / Blockers / Ahead / Next, then a
   cross-project leverage ranking. A **bare** run overwrites the whole file —
   currency is its only virtue. A **scoped** run rewrites only the named
   project's block, leaves every other block exactly as found, and says in the
   briefing which blocks are now older than the file. Refreshing a block from a
   read that never happened is the failure this split exists to prevent, and a
   scoped run has no standing to rank across projects it did not open.
3. **Opens today's daylog** — `hq/<YYYY-MM-DD>-daylog.md` (`artifact: daylog`),
   seeded with the day's plan drawn from the sitrep. If today's daylog already
   exists — a scoped run after the morning's bare one — append the new briefing
   under its own heading; never reseed it, the appends so far are the day.
4. **Flags hygiene debt** noticed in passing to @linn — radar doesn't fix it.

Return the briefing to the window. Filing (path, frontmatter, dashboard
exclusions) is `~/Dev/notes/_saving.md` — read it; seed formats in `_templates/`.
