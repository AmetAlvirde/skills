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

**A day is a working session, not a calendar date** (ruled 2026-08-09,
[[2026-08-08-midnight-boundary-and-day-close-policy]]):

- **Seal at log-out, not at midnight.** A session that runs `18:00 → 03:12`
  seals at `03:12`. The ritual is keyed to when the human stops working, because
  a midnight-keyed one fails on exactly the nights worth recording — the ritual
  competes with the work, and the work wins.
- **Session-day filing.** One unbroken session lives in **one** daylog, under
  the date it began, and the close line states the true span including the
  `(+1d)`. Past-midnight work does **not** get refiled under the new date;
  fragmenting a continuous narrative is the cost, and the machine-checkable half
  reconstructs from `git` anyway.
- **Mint the daylog if it is missing.** Any write to the day's log creates it
  from the template — `/standup` enriches a daylog, it is not the only thing
  that can make one. A day that never opened cannot be appended to, which is
  precisely how 2026-08-07 was lost.

Radar:

1. **Reviews the day** — the daylog's appends, plus the day's commits and new
   artifacts, per `~/Dev/notes/_saving.md`.
2. **Reads what the trackers recorded** — what closed this session, and what was
   filed into them:

   ```sh
   gh search issues --owner @me --state closed --closed ">=<session-start date>" \
     --json repository,number,title,closedAt,url
   gh search issues --owner @me --created ">=<session-start date>" \
     --json repository,number,title,state,createdAt,url
   ```

   **Always a `>=` range from the date the session began, never an exact date,
   and convert every timestamp to local before filing it.** GitHub stamps UTC: at
   `UTC-6`, everything filed after `18:00` local carries *tomorrow's* UTC date.
   Run at `22:43` on 2026-08-09, `--created 2026-08-09` returns **zero** on a day
   that filed nine issues — and an empty result reads as *nothing happened*,
   which is the precise failure this read exists to close. The range form is also
   the one that composes with session-day filing above: one unbroken session, one
   daylog, one query window, `(+1d)` and all.

   **An issue closed this session is proven progress** — it clears the evidence
   gate on its own and belongs in the seal beside the day's commits. **An issue
   filed this session is carried work, not moved work**: record it so tomorrow's
   standup starts from it, and check nothing off for it. Degrade as standup does
   — `gh` failing means `trackers: NOT READ — <reason>` in the seal, never a
   silent gap that later reads as a quiet day.
3. **Seals the session's daylog** — appends the close: what moved, what carries
   to tomorrow, and the session's true span. The daylog keeps forever — it's the
   authored day journal. **A scoped run does not seal.** *Moved* and *carries to
   tomorrow* are claims about the whole day, and a run that read one project
   cannot make them. It appends its debrief under its own heading, leaves
   `## Seal` unwritten, and says in the report that the day is still open. A day
   seals once — a scoped seal would leave a later bare run resealing, which is
   the reseed `/standup` already refuses.
   **Mark unwitnessed work.** A block covering work the human did not watch —
   an agent running while they slept — carries an explicit `unwitnessed` marker,
   or three weeks later it reads as their own reasoning. Conversely, **first-hand
   testimony is evidence**: what the human says happened is recorded as
   testimony, attributed as such, and outranks silence in the git record. `git`
   proves what landed and when, never who was at the desk.
4. **Writes back to project HEADs, evidence-gated** — checks off tasks the day
   proved done, refreshes a Ball that lags, each citing the proof. Never invents
   status, never touches Ahead/Parked, defers to any HEAD a `/handoff` moved
   today. (Full rules live in radar's charter.) **Scope needs no extra rule
   here:** each write is gated on its own evidence and lands in its own file, so
   a HEAD nobody opened stays exactly as it was. This is where hotwash parts
   from standup — `SITREP.md` is one file whose currency is collective, so an
   unwritten block goes stale under a refreshed whole; HEADs are n files whose
   currency is individual.
5. **Flags hygiene debt** to @linn.

## The stash — when a full hotwash is too expensive

At `01:00` the ritual above is too heavy to run and too easy to defer, and
deferring it is what loses the irrecoverable half. So when the human notices
it's late, **three lines appended to the open daylog** — what I'm mid-way
through · what I just decided and why · what I'd start with next — and the full
seal waits for the actual stop.

That is the entire payload that decays by morning. Commits, PRs and artifacts
reconstruct fine; what is mid-thought does not. **That ranks what a three-line
stash may safely drop — it is not a ruling that trackers stay outside the
ritual.** They reconstruct *because* step 2 goes and gets them. Left unread an
issue doesn't decay, which is worse: it never surfaces at all, and a board can
grow eightfold in one evening without a single briefing noticing. A stash skips
that read like every other step. A stash is not a seal, does not write back to
any HEAD, and does not close the day.

Report what moved and every HEAD write with its evidence. Filing is
`~/Dev/notes/_saving.md`.
