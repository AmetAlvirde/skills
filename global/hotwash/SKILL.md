---
name: hotwash
description: >-
  Log-out debrief across the day. Run at the end of a working day to seal what
  moved, carry what didn't, and write the day's proven progress back to project
  HEADs. Pairs with /standup; same debrief family as aar — aar closes an
  increment, hotwash closes a day.
disable-model-invocation: true
---

# hotwash

The log-out ritual: close the day and leave the record truer than you found it.
Spawn **@radar** to run it per its charter — the evidence gate is the
load-bearing part.

Radar:

1. **Reviews the day** — the daylog's appends, plus the day's commits and new
   artifacts, per `~/Dev/notes/_saving.md`.
2. **Seals today's daylog** — appends the close: what moved, what carries to
   tomorrow. The daylog keeps forever — it's the authored day journal.
3. **Writes back to project HEADs, evidence-gated** — checks off tasks the day
   proved done, refreshes a Ball that lags, each citing the proof. Never invents
   status, never touches Ahead/Parked, defers to any HEAD a `/handoff` moved
   today. (Full rules live in radar's charter.)
4. **Flags hygiene debt** to @linn.

Report what moved and every HEAD write with its evidence. Filing is
`~/Dev/notes/_saving.md`.
