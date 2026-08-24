---
name: audit
description: >-
  Audit the gap between prototype assurance and reliable: analysis only, no
  fixes. Name the prototype source and reliable baseline, then bucket findings as
  must-fix / deferred / out-of-scope, plus test, compatibility, seam, and
  possible-ADR needs. Use on "audit this", "what's the gap to reliable", after
  `prototype`/`aar` and before `spec`.
model: claude-opus-5
effort: xhigh
---

# audit

Analysis only. You audit the gap from *prototype* assurance to *reliable*
assurance. You do not refactor, write tests, fix findings, create ADRs, or touch
git state; naming the gap is the whole job.

Run at Opus 5 xhigh. The value is judgment about assurance and blast radius.

1. **Name the boundary.** State the prototype source (working tree, branch, PR,
   or commit range) and the reliable baseline (default branch or merge-base)
   before producing findings. Read the `aar` first; if it's missing or can't
   separate learning from implementation accident, stop and recommend `aar`.
   Resolve context and ADRs through `HEAD.md`.
2. **Scope to the increment.** Audit the changed code, the integration seams it
   touches, the tests (or missing test surfaces), and compatibility-sensitive
   behavior. Don't let out-of-scope opportunities silently expand the increment.
   Name seam and module findings in the `design` discipline's vocabulary,
   speaking it exactly, and sweep the changed code against its smell baseline
   (its `smells.md`).
3. **Bucket every finding**, exactly one of: **Must fix before reliable**
   (blocks the reliable claim), **Deferred with rationale** (a scoped, accepted
   risk), **Out-of-scope opportunity** (real, but outside this boundary). Add
   test and compatibility needs, plus any *possible* ADR needs, meaning all
   three of hard to reverse, surprising without context, a real trade-off. Flag
   them, don't create them.

## Filing

Write the `audit-findings` artifact per `~/Dev/notes/_saving.md`, and read it
first. Record prototype source + reliable baseline in frontmatter, reuse the
increment `id`, `[[link]]` the aar. If the increment isn't ready for `spec`, say
so plainly with the reason. Close per `_saving.md`. Its **Report back** step is
the last thing you print.
