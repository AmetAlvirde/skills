---
name: issues
description: >-
  Decompose an approved spec into tracer-bullet vertical slices — narrow,
  complete, independently reviewable — and publish them as tracker issues after
  approval. Use on "slice this", "break the spec into issues", after `spec` is
  approved and before `implement`.
disable-model-invocation: true
model: claude-opus-4-8
effort: high
---

# issues

Cut the spec into tracer bullets: each slice goes end-to-end through the
increment — narrow, complete, demoable or verifiable on its own, independently
reviewable, tied to a spec requirement. The spec is the source of truth; don't
mine scratch notes.

Run at Opus 4.8 high — slicing is the judgment that makes the build reviewable.

1. **Load the spec + seams** — read the approved spec (resolve through
   `HEAD.md`) and explore enough code to know the affected seams (per the
   `design` discipline's vocabulary). Check ADR consistency: block if the spec
   references a missing/superseded ADR or contradicts an accepted one in a way
   that would make slices misleading.
2. **Slice as tracer bullets** — each slice carries the domain behavior, data,
   interface, and tests it needs. Reject weak slices (only-DB, only-UI,
   only-tests, only-plumbing) unless named explicitly as a foundational,
   migration, or seam/refactor slice. Title in third-person present naming the
   outcome ("Adds invitation acceptance flow").
3. **Write each brief to survive drift** — durability beats precision. Name
   types, signatures, and behavioral contracts; leave out file paths and line
   numbers, which go stale before an agent reads them. State the behavior the
   slice must exhibit, not the procedure for building it. Close every brief with
   acceptance criteria that are complete and verifiable without the brief, and
   an explicit out-of-scope line.
4. **Preview, then publish** — show a numbered breakdown (purpose, coverage,
   blocked-by, reliability/compatibility/test obligation) and iterate until the
   human approves. Publish blockers first so real ids can be referenced.

## Filing

Slices live in the tracker (publish via `gh` after approval); git/PR mechanics
go via @tux. Update `HEAD.md` with the slice set. `implement` builds them one at
a time (@bit).
