---
name: refactor
description: >-
  Diagnose a refactor increment: name the friction, the behavior-preserving
  outcome, the seams, and a candidate reliable increment. Analysis that frames
  the build; @bit executes the slices via `implement`. Use on "refactor this",
  "diagnose the refactor", when reliability / testability / coupling is the
  driver rather than a product feature.
model: claude-opus-5
effort: high
---

# refactor

A refactor needs no visible product behavior, but it must have a verifiable
reliability, testability, compatibility, or module-depth outcome, never "make
it nicer". This skill _diagnoses and frames_; @bit then builds
behavior-preserving slices via `implement`.

Run at this invocation's configured tier. Diagnosis is judgment about seams and
blast radius.

1. **Inspect the friction.** Read the code, tests, and relevant ADRs around the
   reported friction (resolve context through `HEAD.md`). Look for duplicated
   behavior, shallow modules, brittle seams, missing test surfaces,
   compatibility risk. Name them in the `design` discipline's vocabulary (it
   defines seam, depth, locality; its `deepening.md` prices deepening
   candidates).
2. **Diagnose, one question at a time.** Resolve the friction, affected
   behavior/seams, why now, reliability/compatibility impact, non-goals, and the
   candidate reliable increment. If the code answers a question, read it instead
   of asking.
3. **Frame valid outcomes**: testable behavior at a stable seam, duplication
   removed, a deep module extracted, coupling reduced, a brittle boundary
   replaced. Prefer behavior-preserving tracer / seam-creation /
   characterization slices over move-files / rename / add-abstraction.
4. **Request one retry only when blocked.** If an important seam or
   compatibility blast radius remains ungrounded after reading the code, return
   `Retry recommended: <reason>` and point to `/refactor-retry <reason>` instead
   of filing an incomplete diagnosis. That command starts a fresh xhigh turn;
   it is not an in-flight tier change. Do not recommend it merely for wider
   coverage or after an already retried pass.

## Filing

Write the `refactor-diagnosis` artifact per `~/Dev/notes/_saving.md`, and read
it first. Reuse the increment `id`, `[[link]]` the source. If a decision is hard
to reverse, surprising without context, and a real trade-off, run `adr`. Build
routes through `implement` (@bit). Close per `_saving.md`. Its **Report back**
step is the last thing you print.
