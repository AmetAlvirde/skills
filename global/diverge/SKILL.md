---
name: diverge
description: >-
  The divergence method — expand a subject into the territory to consider before
  any plan: branches, hierarchically numbered nodes, dependencies, hotspots,
  unknowns; then file the map artifact. Model-invoked discipline composed by
  `map` and other specialized maps; not run directly.
user-invocable: false
---

# diverge

Expand a subject into the **territory to consider** before any plan, PRD, or
strategy. This is the breadth move — surface, don't resolve (resolving is
`converge`).

The invoking front door sets the subject, the tier, and the **lens** — which
dimensions matter in that domain, and what a hotspot looks like there. Absent a
lens, cast wide across the general dimensions below.

1. **Restate the idea** in 1–3 sentences the user agrees with; sharpen with a
   question or two first if it's too fuzzy to restate faithfully.
2. **Branch it** — the top-level dimensions a plan must address (scope, users,
   domain model, constraints, dependencies, risks, sequencing, success signal…).
   Cast wide.
3. **Expand each branch** into its considerations and unknowns. **Number nodes
   hierarchically** (1, 1.1, 1.2…) so any node is addressable by `converge`. A
   node is **open** unless annotated — `[resolved → [[grill]]]` or `[dropped —
   <reason>]`. Annotate only on change; `converge` writes these back as it
   closes nodes, so an un-annotated node is a live question.
4. **Map dependencies** — which nodes gate others; the upstream load-bearing
   set.
5. **Flag hotspots** — highest-uncertainty / highest-leverage nodes (converge
   first).
6. **Point downstream** — what this map feeds and the recommended next move.

A map is a scaffold for thinking, not the thinking itself — breadth over depth.
It is also **living**: grills mutate it in place, so a re-read shows what is
still open. Never fork a resolved map into a new file — edit the original.

When a branch outgrows the map, split it into its own map and leave the parent
node as a `[[link]]` to it. That is how several maps compose; there is no
container above the map.

## Filing

Save per `~/Dev/notes/_saving.md` — **read it**; source of truth for path,
frontmatter, HEAD update, wikilinks, and the closing report. This one:
`artifact: map`, file `<project>/<YYYY-MM-DD>-<topic>-map.md`,
`repo`/`repo_path` from cwd; start the increment `id` here (later grills/PRDs
reuse it). If a durable, transferable insight surfaced, run the valve
(`_conventions.md` §4). Offer to commit, then close per `_saving.md` — its
**Report back** step is the last thing you print.
