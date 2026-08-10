---
name: hotwash
description: >-
  Log-out debrief. Bare, it spans the whole day — sealing what moved, carrying
  what didn't, and writing the day's proven progress back to project HEADs.
  Given a project or target, it debriefs only that and leaves the day open.
  Pairs with /standup; same debrief family as aar — aar closes an increment,
  hotwash closes a day.
disable-model-invocation: true
---

# hotwash

The log-out ritual: close the day and leave the record truer than you found it.
Spawn **@radar** to run it per its charter — the evidence gate is the
load-bearing part.

**Debrief at the smallest scope that answers what was asked** — the same
contract `/standup` and `/enn` run:

- **An argument naming a project or target** (`numisma`, a repo): that IS the
  scope. Review the day's commits and new artifacts in that project, and the
  daylog appends that concern it — no other project's HEAD, not to rank against
  them, not to "confirm" a scope you were handed.
- **Bare `/hotwash`**: only then the whole day.

Radar:

1. **Reviews the day** — the daylog's appends, plus the day's commits and new
   artifacts, per `~/Dev/notes/_saving.md`.
2. **Seals today's daylog** — appends the close: what moved, what carries to
   tomorrow. The daylog keeps forever — it's the authored day journal. **A
   scoped run does not seal.** *Moved* and *carries to tomorrow* are claims
   about the whole day, and a run that read one project cannot make them. It
   appends its debrief under its own heading, leaves `## Seal` unwritten, and
   says in the report that the day is still open. A day seals once — a scoped
   seal would leave a later bare run resealing, which is the reseed `/standup`
   already refuses.
3. **Writes back to project HEADs, evidence-gated** — checks off tasks the day
   proved done, refreshes a Ball that lags, each citing the proof. Never invents
   status, never touches Ahead/Parked, defers to any HEAD a `/handoff` moved
   today. (Full rules live in radar's charter.) **Scope needs no extra rule
   here:** each write is gated on its own evidence and lands in its own file, so
   a HEAD nobody opened stays exactly as it was. This is where hotwash parts
   from standup — `SITREP.md` is one file whose currency is collective, so an
   unwritten block goes stale under a refreshed whole; HEADs are n files whose
   currency is individual.
4. **Flags hygiene debt** to @linn.

Report what moved and every HEAD write with its evidence. Filing is
`~/Dev/notes/_saving.md`.
