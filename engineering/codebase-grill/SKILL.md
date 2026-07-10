---
name: codebase-grill
description: >-
  Grill a decision against the live codebase — load product / glossary / ADR
  context, then interrogate one numbered question at a time until user and agent
  share understanding. The project-scoped evolution of `grill`. Use on
  "codebase-grill", "grill this against the code", "pressure-test this decision
  in-repo".
disable-model-invocation: true
model: claude-opus-4-8
effort: high
---

# codebase-grill

A thin front door: load what the repo already knows, then converge with that
context in hand. The point over bare `grill` is that facts are looked up in the
code, not asked of the human.

1. **Load repo context** — resolve product doc, glossary, and ADRs through the
   project's `HEAD.md` frontmatter (per `~/Dev/notes/_saving.md`). Read enough
   to answer factual questions yourself.
2. **Compose `converge`** on the target decision. Lens: with the codebase in
   reach, **facts → look them up** in the code and docs you just loaded;
   **decisions → always the human's**. A weak joint here is a decision that
   contradicts what the code, glossary, or an ADR already commits to — surface
   the conflict rather than grilling around it. Do not enact anything until the
   user confirms shared understanding.
3. **Exit** — `converge`'s convergence and artifact apply unchanged.

## Filing

`converge` writes the artifact (`artifact: grill`) per `~/Dev/notes/_saving.md`
— read it. Reuse the increment's `id`, note that context came from the repo, and
`[[link]]` the source map. Close by updating `HEAD.md`; offer to commit.
