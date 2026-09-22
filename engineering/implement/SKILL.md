---
name: implement
description: >-
  Implement one reliable vertical slice: red test at the seam, green, verify;
  narrow and independently reviewable. The build loop runs as @bit. Use on
  "implement this slice", "build the slice", or after `spec`/`issues` define a
  slice.
---

# implement

One reliable slice at a time, not the whole spec. Reliable means tested at the
seam and behavior-preserving everywhere else (seam and interface per the
`design` discipline, where the interface is the test surface).

Multi-turn build loop. Run it as **@bit** (Opus 5.5 medium holds the tier); the
skill frames the slice, @bit writes red→green and runs the cadence, @tux
commits.

1. **Load the slice contract.** Read the slice and its parent spec (resolve
   through `HEAD.md`); read only the relevant ADRs and the seams/tests the slice
   touches. If the slice contradicts the spec or an ADR, stop and get the
   contract fixed before coding.
2. **Tracer bullet, red first.** Cut the thinnest end-to-end slice that proves
   the seam; write the failing test at the pre-agreed seam, make it pass, then
   run the typecheck/test cadence. Preserve existing behavior; use the project's
   test patterns; no speculative scope.
3. **Verify the reliable claim.** Run targeted commands plus any suite the
   claim needs; if one can't run, say why and name the residual risk.

## Filing

Finished green work goes to **@tux** to commit. You do not commit or close the
tracker issue (a human call). Update `HEAD.md` with the slice result and
verification per `~/Dev/notes/_saving.md`. The code and tests are the durable
artifact; no separate vault note unless a lesson surfaces (then run the valve).
