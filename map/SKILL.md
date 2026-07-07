---
name: map
description: >-
  Turn a raw idea into a structured map of everything to consider before
  planning — the branches, decisions, dependencies, and unknowns that any plan,
  PRD, or strategy for the idea must address. Use when the user says "map", "map
  this out", "help me think through X", or has a fuzzy idea and wants the whole
  consideration space laid out before committing to a plan. Produces a map
  artifact in ~/Dev/notes. Diverges (breadth); pair with grill to converge.
---

# map

Take a simple idea and expand it into a **map of the territory** — the branches of
consideration, the decisions each branch contains, the dependencies between them,
and the unknowns — so the user can see the whole space before writing a plan, PRD,
or strategy.

Map is the **breadth** move: it casts wide and surfaces, it does **not** resolve.
Its complement is `grill`, the **depth** move that walks down one branch and
converges. A map produces numbered nodes precisely so any node can later be handed
to `grill`.

## When to use / not use

- **Use** at the fuzzy front end — an idea exists but the shape of the work
  doesn't. Before a plan/PRD/strategy, when you don't yet know what you're
  deciding.
- **Not** for resolving a decision (that's `grill`) or for reconstructing state
  (that's `handoff`). If the idea is already sharp and the branches known, skip
  straight to grilling or planning.

## The mapping process

1. **Restate the idea** in one to three sentences the user agrees with. If it's
   too fuzzy to restate faithfully, ask one or two sharpening questions first —
   then restate.
2. **Decompose into branches** — the top-level dimensions any plan for this idea
   must address (e.g. scope & boundaries, users, data/domain model, constraints,
   dependencies, risks, sequencing, success signal). Cast wide. This is a breadth
   pass — surface considerations, don't resolve them.
3. **Expand each branch** into its specific considerations, sub-questions, and
   unknowns. **Number nodes hierarchically** (1, 1.1, 1.2, 2, 2.1, …) so any node
   is individually addressable by `grill`.
4. **Map the dependencies** — which nodes gate others? Record edges like "3.2
   can't be decided until 1.1 is settled." Call out the upstream, load-bearing
   nodes that unlock the most.
5. **Flag the hotspots** — the highest-uncertainty and highest-leverage nodes; the
   ones worth grilling first.
6. **Point downstream** — name what this map feeds (a PRD, a strategy doc, a grill
   of node X) and recommend the concrete next move.

Keep it navigable, not exhaustive: a map is a scaffold for thinking, not the
thinking itself. Breadth over depth; the depth comes later, in grill.

## Artifact shape

Suggested sections:

- **The idea** — the agreed restatement.
- **The map** — the numbered branch/node tree, each node carrying its
  considerations and unknowns (not answers).
- **Dependencies** — the gating edges between nodes; the upstream load-bearing set.
- **Hotspots (grill these first)** — highest-uncertainty / highest-leverage nodes.
- **Feeds / next move** — what this map is upstream of, and the recommended step
  (usually: grill node X, or draft the PRD once nodes A–C are grilled).

## Filing the artifact (house rules)

The artifacts live in `~/Dev/notes`, a git-backed Obsidian vault. **Read
`~/Dev/notes/_conventions.md` first** — it is the source of truth and may have
changed. Current essentials:

- **Path:** `~/Dev/notes/<project>/<YYYY-MM-DD>-<topic>-map.md`. Prefixless; date
  first; lowercase project folder matching the `repo` value. Get the real date
  with `date +%Y-%m-%dT%H:%M`.
- **Project:** infer from the cwd (e.g. `/Users/amet/Dev/numisma` → `numisma`). If
  the idea isn't tied to a known project folder yet, confirm with the user or
  stage in `~/Dev/notes/_inbox/`.
- **Frontmatter** (required: `repo`, `artifact`, `created`):
  ```yaml
  ---
  repo: <project>
  repo_path: <cwd, if a local clone exists>   # else repo_url:
  id: <YYYY-MM-DD-topic>                       # start the increment id here — later grills/PRDs reuse it
  cycle: none
  artifact: map
  assurance: discovery
  publishable: false
  created: <YYYY-MM-DDThh:mm>                   # real date+time
  ---
  ```
  (`map` is a deliberate addition to the `_conventions.md` §3 artifact vocab — it
  is the breadth-pass complement to `grill`.)
- **Wikilinks:** reference other notes by basename.
- **HEAD (closing step, do not skip):** update `<project>/HEAD.md` — the ball is
  now "map done; grill node X next." Add the grill(s) as `## Next actions` with
  mood fields. Copy `~/Dev/notes/_templates/HEAD.md` if the project has no HEAD.
- **Valve:** if a durable, transferable insight surfaced, flag it for promotion to
  conscium (§4).
- Offer to `git add` + commit the note when done.
