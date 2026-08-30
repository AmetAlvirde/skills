---
name: codebase-map
description: >-
  Map an idea against the live codebase. Load product / glossary / ADR context,
  survey the code, then diverge with the repo as the lens: what's touched, what
  already exists, what the code commits to. The project-scoped evolution of
  `map`. Use on "codebase-map", "map this against the code", "map this feature
  in-repo".
model: claude-opus-5
effort: high
---

# codebase-map

A thin front door: load what the repo already knows, then diverge with that
context in hand. The point over bare `map` is that factual nodes collapse. You
look them up in the code instead of leaving them as open considerations.

1. **Load repo context.** Resolve product doc, glossary, and ADRs through the
   project's `HEAD.md` frontmatter (per `~/Dev/notes/_saving.md`). Divergence
   needs breadth across the repo: fan reconnaissance out to Explore sub-agents
   and keep only conclusions.
2. **Compose `diverge`** on the idea. Lens: slant the branches toward the code.
   Cover touched subsystems and data models, existing seams to reuse vs. build
   new (seam per the `design` discipline's vocabulary), what ADRs, contracts,
   and the glossary already commit to, blast radius, and the sequencing the
   code's shape forces. Looking up a fact is not resolving a decision: collapse
   what the code answers; every genuine decision stays an open node for the
   grill. A node that contradicts an existing commitment is a hotspot by
   definition. Anchor nodes to files and directories, pointers that stay valid
   as the code moves.
3. **Exit.** `diverge`'s downstream pointer and artifact apply unchanged; the
   natural next move is `codebase-grill` on the hotspots.

## Filing

`diverge` writes the artifact (`artifact: map`) per `~/Dev/notes/_saving.md`;
read it first. Start the increment `id` here; note that context came from the
repo. Offer to commit, then close per `_saving.md`. Its **Report back** step is
the last thing you print.
