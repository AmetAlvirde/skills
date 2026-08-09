---
name: spec
description: >-
  Synthesize a spec from an already-agreed understanding — never interview.
  Confirm the seams before writing, publish to GitHub, and file the spec
  artifact. Use on "write the spec", "spec this", "turn this into a PRD".
---

# spec

Synthesize, don't interview. By the time you write a spec the thinking is done
(via `map`/`grill`); your job is to render it faithfully and confirm the seams.

Run it as **@vera** — the definer holds Opus 5 high across the confirm→approve
loop a skill pin would drop at the next turn, and owns the xhigh escalation for
when the synthesis fights back. The run ends at an approved spec; the build is
someone else's session.

1. **Gather the agreed understanding** — pull from the increment's map and
   grills (resolve them through `HEAD.md`); do not re-open settled decisions.
2. **Confirm the seams before writing** — name the seams the build will cut
   along (modules, contracts, tracer-bullet slices), in the `design`
   discipline's vocabulary. If a seam is still fuzzy,
   compose `converge` on that one seam — lens: a weak joint is a boundary the
   build can't cut along; otherwise state each seam and get a nod.
3. **Write the spec** — problem, the confirmed seams, slices, and the verifiable
   success signal. No interview transcript; the spec is the synthesis.
4. **Publish** — push to GitHub as the durable home (via @tux for any git/PR
   mechanics).
5. **File** — the vault keeps the spec artifact.

## Filing

Save per `~/Dev/notes/_saving.md` — read it. `artifact: spec`, reuse the
increment's `id`, `[[link]]` the source map and grills. If a durable,
transferable lesson surfaced, run the valve (`_conventions.md` §4). Offer to
commit, then close per `_saving.md` — its **Report back** step is the last thing
you print.
