---
name: spec
description: >-
  Synthesize a spec from an already-agreed understanding — never interview.
  Confirm the seams before writing, publish to GitHub, and file the spec
  artifact. Evolves mvi-prd. Use on "write the spec", "spec this", "turn this
  into a PRD".
disable-model-invocation: true
model: claude-sonnet-4-6
---

# spec

Synthesize, don't interview. By the time you write a spec the thinking is done
(via `map`/`grill`); your job is to render it faithfully and confirm the seams.

1. **Gather the agreed understanding** — pull from the increment's map and grills
   (resolve them through `HEAD.md`); do not re-open settled decisions.
2. **Confirm the seams before writing** — name the boundaries the build will cut
   along (modules, contracts, tracer-bullet slices). If a seam is still fuzzy,
   compose `grill` on that one seam; otherwise state each seam and get a nod.
3. **Write the spec** — problem, the confirmed seams, slices, and the verifiable
   success signal. No interview transcript; the spec is the synthesis.
4. **Publish** — push to GitHub as the durable home (via @tux for any git/PR
   mechanics).
5. **File** — the vault keeps the spec artifact.

## Filing

Save per `~/Dev/notes/_saving.md` — read it. `artifact: spec`, reuse the
increment's `id`, `[[link]]` the source map and grills. Close by updating
`HEAD.md`; offer to commit. If a durable, transferable lesson surfaced, run the
valve (`_conventions.md` §4).
