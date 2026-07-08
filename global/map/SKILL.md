---
name: map
description: >-
  Turn a raw idea into a structured map of everything to consider before
  planning — branches, decisions, dependencies, unknowns. Use on "map", "map
  this out", "help me think through X", or a fuzzy idea needing its space laid
  out. Writes a map artifact to ~/Dev/notes. Breadth pass; pair with grill to
  converge.
---

# map

Expand an idea into the **territory to consider** before any plan, PRD, or
strategy. This is the breadth move — surface, don't resolve (resolving is
`grill`).

1. **Restate the idea** in 1–3 sentences the user agrees with; sharpen with a
   question or two first if it's too fuzzy to restate faithfully.
2. **Branch it** — the top-level dimensions a plan must address (scope, users,
   domain model, constraints, dependencies, risks, sequencing, success signal…).
   Cast wide.
3. **Expand each branch** into its considerations and unknowns. **Number nodes
   hierarchically** (1, 1.1, 1.2…) so any node is addressable by `grill`.
4. **Map dependencies** — which nodes gate others; the upstream load-bearing
   set.
5. **Flag hotspots** — highest-uncertainty / highest-leverage nodes (grill
   first).
6. **Point downstream** — what this map feeds and the recommended next move.

A map is a scaffold for thinking, not the thinking itself — breadth over depth.

## Filing

Save per `~/Dev/notes/_saving.md` — **read it**; source of truth for path,
frontmatter, HEAD update, and wikilinks. This one: `artifact: map`, file
`<project>/<YYYY-MM-DD>-<topic>-map.md`, `repo`/`repo_path` from cwd; start the
increment `id` here (later grills/PRDs reuse it). Close by updating
`<project>/HEAD.md` and offering to commit. If a durable, transferable insight
surfaced, run the valve (`_conventions.md` §4).
