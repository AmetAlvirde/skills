---
name: standup
description: >-
  Log-in briefing across every project. Run at the start of a working day to see
  where each project stands and where the next move has most leverage. Refreshes
  the rolling hq/SITREP.md and opens today's daylog seeded with the plan.
disable-model-invocation: true
---

# standup

The log-in ritual: one cross-project read that tells you where to spend the day.
Spawn **@radar** to produce it per its charter (leverage ranking, pointer
resolution, the linn boundary).

Radar:

1. **Reads the field** — every project `HEAD.md` + recent artifacts, per
   `~/Dev/notes/_saving.md`.
2. **Refreshes `hq/SITREP.md`** — the rolling briefing (`artifact: sitrep`,
   undated, always-current): per-project Ball / Blockers / Ahead / Next, then a
   cross-project leverage ranking. Overwrites the prior sitrep — currency is its
   only virtue.
3. **Opens today's daylog** — `hq/<YYYY-MM-DD>-daylog.md` (`artifact: daylog`),
   seeded with the day's plan drawn from the sitrep. It's the working surface you
   append to through the day and hotwash seals.
4. **Flags hygiene debt** noticed in passing to @linn — radar doesn't fix it.

Return the briefing to the window. Filing (path, frontmatter, dashboard
exclusions) is `~/Dev/notes/_saving.md` — read it; seed formats in `_templates/`.
