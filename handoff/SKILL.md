---
name: handoff
description: >-
  Capture the working state so a fresh agent resumes with zero prior context.
  Use on "handoff", "wrap up / close this context", "running low on context", or
  a session ending mid-task. Writes a handoff artifact to ~/Dev/notes and
  updates the project HEAD.
---

# handoff

Reconstruct the current state for an agent with **zero prior context**: capture
what they'd otherwise re-derive, omit what they can read from the repo. The
audience is the next agent, not the user.

Pull from the conversation **and** live repo state; write only what's
load-bearing:

- **Where we are** — the increment and current step.
- **Decisions locked** — numbered, attributed to who decided.
- **Code on the branch** — what changed (`file:line`), committed vs. not, and
  how it was verified (what you actually ran).
- **Key facts** — shapes, invariants, gotchas; each marked **verified** or
  **assumed**.
- **Pending** — durable/irreversible actions awaiting the user's go.
- **Open questions** — highest-value one first.
- **Do next** — the one concrete first action.
- _(only if it changes how they work)_ **Your role** — e.g. orchestrate, protect
  context.

Honesty rule: report what you ran vs. assumed; never claim an unrun check
passed.

## Filing

Save per `~/Dev/notes/_saving.md` — **read it**; it's the source of truth
for path, frontmatter, HEAD update, and wikilinks. This one:
`artifact: handoff`, file `<project>/<YYYY-MM-DD>-<topic>-handoff.md`,
`repo`/`repo_path` from cwd, add `git_branch`. Close by updating
`<project>/HEAD.md` and offering to commit. If the session yielded a durable,
transferable lesson, run the valve (`_conventions.md` §4).
