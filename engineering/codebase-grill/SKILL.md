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
effort: xhigh
---

# codebase-grill

A thin front door: load what the repo already knows, then run the `grill`
discipline with that context in hand. The point over bare `grill` is that facts
are looked up in the code, not asked of the human.

1. **Load repo context** — resolve product doc, glossary, and ADRs through the
   project's `HEAD.md` frontmatter (per `~/Dev/notes/_saving.md`). Read enough to
   answer factual questions yourself.
2. **Compose `grill`** — run the `grill` discipline on the target decision.
   Enforce its split with the codebase in reach: **facts → look them up** in the
   code and docs you just loaded; **decisions → always the human's**. Do not
   enact anything until the user confirms shared understanding.
3. **Exit** — `grill`'s convergence and artifact apply unchanged.

## Filing

`grill` writes the artifact (`artifact: grill`) per `~/Dev/notes/_saving.md` —
read it. Reuse the increment's `id`, note that context came from the repo, and
`[[link]]` the source map. Close by updating `HEAD.md`; offer to commit.
