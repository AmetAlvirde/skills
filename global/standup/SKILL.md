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
2. **Reads the trackers — one call, never a repo list.**

   ```sh
   gh search issues --owner @me --state open --limit 100 \
     --json repository,number,title,createdAt,updatedAt,labels,url
   gh search prs --owner @me --state open --limit 50 \
     --json repository,number,title,isDraft,url
   ```

   **Never enumerate repos.** A hand-built list is a document, and documents go
   stale about trackers faster than about anything else: the 2026-08-09 survey
   queried nine repos *by name*, believed it had verified the whole estate, and
   still missed `super-solarized#1` — a repo `devex/HEAD.md` had been listing
   since that morning. `@me` has no list to keep true and costs about a second.
   **A scoped run filters this one result, it does not re-query** — keep the rows
   whose repo the scope names, resolved from that HEAD's `repo_path` /
   `repo_url` / `repos:` (`_conventions.md` §7).

   **A tracker row is not a task; it is evidence for one.** Rank moves, not
   surfaces — eleven issues must not crowd out six Balls merely by being
   countable. Two things promote a row: **a defect in a floor other work stands
   on outranks feature work** (`skills#2`/`#3` are bugs in the branch guard every
   repo runs, and nothing briefed them for a day), and **age is signal** — a row
   untouched for weeks is dead or dropped, so say which rather than re-listing it.

   **Degrade, never block.** This read is additive. `gh` exits non-zero on auth
   failure, offline and rate limit alike, so catch it, brief from the HEADs
   anyway, and print one explicit line — `trackers: NOT READ — <reason>`. A
   cached snapshot from `SITREP.md` may stand in **only when labelled with its
   age**, never as current. A briefing that hard-fails offline gets switched off,
   exactly as a guard that blocks on its own confusion does. Silence is the one
   forbidden output: **"no open issues" and "I could not look" must never render
   the same.**
3. **Refreshes `hq/SITREP.md`** — the rolling briefing (`artifact: sitrep`,
   undated, always-current): per-project Ball / Blockers / Ahead / Next, then a
   cross-project leverage ranking. A **bare** run overwrites the whole file —
   currency is its only virtue. A **scoped** run rewrites only the named
   project's block, leaves every other block exactly as found, and says in the
   briefing which blocks are now older than the file. Refreshing a block from a
   read that never happened is the failure this split exists to prevent, and a
   scoped run has no standing to rank across projects it did not open. **Cache
   the tracker snapshot here**, stamped with the UTC time of the call, so a later
   failed read has something honest to fall back on.
4. **Opens today's daylog** — `hq/<YYYY-MM-DD>-daylog.md` (`artifact: daylog`),
   seeded with the day's plan drawn from the sitrep. If today's daylog already
   exists — a scoped run after the morning's bare one — append the new briefing
   under its own heading; never reseed it, the appends so far are the day.
   **Standup enriches a daylog; it is not the only thing that can create one.**
   Any write to the day's log mints it from the template if absent, so a day is
   never unopenable (ruled 2026-08-09,
   [[2026-08-08-midnight-boundary-and-day-close-policy]]). And check whether
   last night's session is still unsealed before opening a new file: under
   **session-day filing** a session that ran past midnight belongs to the daylog
   of the date it *began*, so a standup the next morning may be opening the
   first file of a genuinely new day, or arriving after one that never closed —
   say which.
5. **Flags hygiene debt** noticed in passing to @linn — radar doesn't fix it.
   **A repo with an open row and no HEAD anywhere is hygiene debt** — the read
   found work the vault has no project for (`normalize-fit-file`, 2026-08-09).

Return the briefing to the window. Filing (path, frontmatter, dashboard
exclusions) is `~/Dev/notes/_saving.md` — read it; seed formats in `_templates/`.
