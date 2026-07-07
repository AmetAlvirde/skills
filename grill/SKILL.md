---
name: grill
description: >-
  Scrutinize an idea, or one branch of a map, until user and agent reach shared
  understanding — walk the logic tree, resolve decision dependencies one at a
  time, asking numbered questions each with a recommended answer. Use when the
  user says "grill", "grill this", "pressure-test", "interrogate this decision",
  or wants to nail down a fuzzy area before building. Produces a grill artifact
  in ~/Dev/notes. Converges (depth); pair with map to diverge (breadth).
---

# grill

Take an idea, a decision, or one branch of a `map` and **scrutinize it until the
user and you would describe it the same way** — no load-bearing decision left
fuzzy. Grill walks down each branch of the logic tree, resolving the dependencies
between decisions **one at a time, in order**, and puts a recommended answer on
the table with every question.

Grill is the **depth / convergence** move. Its complement is `map`, the breadth
move that lays out the branches. Grill consumes a map node and returns it resolved.

## When to use / not use

- **Use** to convert a fuzzy area into locked decisions before building — a map
  branch, a single hard decision, or a raw idea sharp enough to interrogate.
- **Not** for surfacing the space (that's `map`) or for reconstructing state
  (that's `handoff`). If you don't yet know what the decisions *are*, map first.

## The grilling protocol

This is an **interactive, one-question-at-a-time** process, not a document
dump. Run it live with the user:

1. **Scope the subject.** State exactly what's being grilled — a specific map node
   (e.g. "node 3.2"), a decision, or an idea. If handed a whole map, ask which
   branch to start with (default: the most upstream / highest-uncertainty one).

2. **Build the logic tree.** Enumerate the decisions the subject depends on, then
   order them **topologically** — a decision others hinge on gets resolved first.
   Show the user the tree/path so they can see where the grilling is headed.

3. **Resolve one decision at a time.** For the current unresolved node, ask a
   single numbered question in this shape:

   > **Q<n>. <the question>**
   > *Why it matters / what it blocks:* <one line>
   > **Recommendation:** <your answer> — <the reasoning; name what would flip it>

   Ask **one** open question at a time. Do not batch independent decisions —
   dependencies must resolve in order so each answer can inform the next. Number
   questions continuously (Q1, Q2, Q3 …) across the whole session.

4. **Record and propagate.** When the user decides, restate the locked decision in
   one line. Then re-derive: does this answer close, open, or change any
   downstream node? Update the tree — sometimes an answer dissolves later
   questions or spawns new ones — then ask the next question.

5. **Walk every branch.** Continue until each branch bottoms out in either a
   **locked decision** or an **explicitly parked** open question. Don't leave a
   silent gap; an unresolved node is either answered or consciously deferred.

6. **Exit on shared understanding.** Stop when you and the user would describe the
   subject the same way and no load-bearing decision is open. Summarize the
   resolved tree back and get explicit confirmation before writing the artifact.

Push back honestly during the grill — the point is to find the weak joints, not to
ratify the first idea. Your recommendation should be a real position with real
reasoning, not a hedge.

## Artifact shape

Write the artifact **after** convergence. Suggested sections:

- **Subject** — what was grilled (link the source `[[map]]` node if there was one).
- **Decisions locked** — numbered, each with a one-line rationale and, where it
  matters, who decided. This is the payload.
- **Open questions (parked)** — nodes consciously deferred, with why and what
  unblocks them.
- **What this feeds** — the PRD / prototype / next grill this unlocks.
- *(Optional)* **Grill trail** — the Q&A sequence, if the reasoning path is worth
  preserving.

Match the house style of existing grills in `~/Dev/notes/<project>/` when one
exists (e.g. Problem / Non-Goals framing) rather than imposing a foreign shape.

## Filing the artifact (house rules)

The artifacts live in `~/Dev/notes`, a git-backed Obsidian vault. **Read
`~/Dev/notes/_conventions.md` first** — it is the source of truth and may have
changed. Current essentials:

- **Path:** `~/Dev/notes/<project>/<YYYY-MM-DD>-<topic>-grill.md`. Prefixless; date
  first; lowercase project folder matching the `repo` value. Get the real date
  with `date +%Y-%m-%dT%H:%M`.
- **Project:** infer from the cwd (e.g. `/Users/amet/Dev/numisma` → `numisma`). If
  the subject isn't tied to a known project folder, confirm with the user or stage
  in `~/Dev/notes/_inbox/`.
- **Frontmatter** (required: `repo`, `artifact`, `created`):
  ```yaml
  ---
  repo: <project>
  repo_path: <cwd, if a local clone exists>   # else repo_url:
  id: <YYYY-MM-DD-topic>                       # reuse the map's id if grilling a map node
  cycle: none
  artifact: grill
  assurance: discovery
  publishable: false
  created: <YYYY-MM-DDThh:mm>                   # real date+time
  ---
  ```
- **Wikilinks:** reference the source map and related notes by basename, e.g.
  `[[2026-07-06-<topic>-map]]`.
- **HEAD (closing step, do not skip):** update `<project>/HEAD.md` — the ball moves
  to whatever the locked decisions unlock (usually a PRD or prototype). Add it to
  `## Next actions` with mood fields. Copy `~/Dev/notes/_templates/HEAD.md` if the
  project has no HEAD yet.
- **Valve:** a grill often yields a durable decision rationale — if it would repeat
  on a different project, flag it for promotion to conscium (§4), distilled fresh.
- Offer to `git add` + commit the note when done.
