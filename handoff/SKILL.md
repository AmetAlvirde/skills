---
name: handoff
description: >-
  Close out a context window by capturing the working state so a fresh agent can
  resume with zero prior context. Use when the user says "handoff", "write a
  handoff", "wrap up / close this context", "I'm running low on context", or when
  a session is ending mid-task. Produces a handoff artifact in ~/Dev/notes and
  updates the project HEAD so the next session knows where the ball is.
---

# handoff

Reconstruct the current working state into a single markdown artifact so an agent
with **zero prior context** can pick up the work exactly where it was left. A good
handoff captures what the next agent would otherwise have to re-derive — and
deliberately omits what they can trivially read from the repo.

## When to use / not use

- **Use** when a session is ending mid-task, context is running low, or the user
  explicitly asks to hand off.
- **Not** a status report for the user — the audience is the *next agent*. Write
  to that reader.

## Writing the handoff

Gather from the conversation **and** the live repo state:

- Current branch, `git status`, and precisely what is committed vs. uncommitted.
- Which increment/task is in flight and where within it you are.
- Decisions the user has **locked** (and who decided them).
- Concrete code changes on the branch, with `file:line` references.
- Hard-won facts (event shapes, invariants, gotchas) — each labelled **verified**
  vs. **assumed**.
- Items pending the user's explicit go (durable or irreversible actions).
- Open questions, with the single highest-value one flagged.
- The one concrete next action.

Suggested sections (adapt to the work — omit what doesn't apply):

- **Your role (read first)** — orientation for the incoming agent (e.g. "you are
  an orchestrator; protect your context window; delegate heavy reads to
  sub-agents"). Include only if it changes how they should work.
- **Where we are** — the increment and the current step.
- **Artifacts** — `[[wikilinks]]` to related grills / maps / research, sharing the
  increment `id`.
- **Decisions locked** — numbered, each attributed to who decided it.
- **Code changes on the branch** — what changed, committed or not, and *how it was
  verified* (what you actually ran).
- **Key facts (so you don't re-derive them)** — `file:line`, exact shapes,
  invariants, runtime gotchas.
- **Pending — needs the user's go** — approvals blocking durable/irreversible work.
- **Open questions** — highest-value one first.
- **Do next** — the concrete first action for the incoming agent.

**Honesty rule:** state what you actually ran and what you only assumed. Never
claim a check passed that you didn't run. Prefer `file:line` over prose the next
agent can't grep.

## Filing the artifact (house rules)

The artifacts live in `~/Dev/notes`, a git-backed Obsidian vault. **Read
`~/Dev/notes/_conventions.md` first** — it is the source of truth and may have
changed. Current essentials:

- **Path:** `~/Dev/notes/<project>/<YYYY-MM-DD>-<topic>-handoff.md`. Prefixless;
  date first; lowercase project folder matching the `repo` value. Get the real
  date with `date +%Y-%m-%dT%H:%M`.
- **Project:** infer from the cwd (e.g. `/Users/amet/Dev/numisma` → `numisma`). If
  the work isn't tied to a known project folder, confirm with the user or stage in
  `~/Dev/notes/_inbox/`.
- **Frontmatter** (required: `repo`, `artifact`, `created`):
  ```yaml
  ---
  repo: <project>
  repo_path: <cwd, if a local clone exists>   # else repo_url:
  id: <YYYY-MM-DD-topic>                       # if part of a multi-artifact increment — reuse the same id
  cycle: none
  artifact: handoff
  assurance: discovery
  publishable: false
  git_branch: <branch>
  created: <YYYY-MM-DDThh:mm>                   # real date+time
  ---
  ```
- **Wikilinks:** reference other notes by basename, e.g.
  `[[2026-07-03-price-fetch-grill]]`.
- **HEAD (closing step, do not skip):** update `<project>/HEAD.md` — move the
  "Ball" line, refresh `## Next actions` (with the `[kind::]` `[depth::]`
  `[timebox::]` `[coldstart::]` mood fields), and list anything now parked. If the
  project has no HEAD yet, copy `~/Dev/notes/_templates/HEAD.md`.
- **Valve:** if the session yielded a durable, transferable lesson, flag it for
  promotion to conscium (§4) — distil fresh, don't transplant the build log.
- Offer to `git add` + commit the note(s) when done.
