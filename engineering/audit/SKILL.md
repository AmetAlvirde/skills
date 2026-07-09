---
name: audit
description: >-
  Audit the gap between prototype assurance and reliable — analysis only, no
  fixes. Name the prototype source and reliable baseline, then bucket findings as
  must-fix / deferred / out-of-scope, plus test, compatibility, seam, and
  possible-ADR needs. Use on "audit this", "what's the gap to reliable", after
  `prototype`/`aar` and before `spec`.
disable-model-invocation: true
model: claude-opus-4-8
effort: high
---

# audit

Analysis only — you audit the gap from *prototype* assurance to *reliable*
assurance. You do not refactor, write tests, fix findings, create ADRs, or touch
git state; naming the gap is the whole job.

Run at Opus 4.8 high — the value is judgment about assurance and blast radius.

1. **Name the boundary** — state the prototype source (working tree, branch, PR,
   or commit range) and the reliable baseline (default branch or merge-base)
   before producing findings. Read the `aar` first; if it's missing or can't
   separate learning from implementation accident, stop and recommend `aar`.
   Resolve context and ADRs through `HEAD.md`.
2. **Scope to the increment** — audit the changed code, the integration seams it
   touches, the tests (or missing test surfaces), and compatibility-sensitive
   behavior. Don't let out-of-scope opportunities silently expand the increment.
3. **Bucket every finding** — exactly one of: **Must fix before reliable** (blocks
   the reliable claim), **Deferred with rationale** (a scoped, accepted risk),
   **Out-of-scope opportunity** (real, but outside this boundary). Add test and
   compatibility needs, plus any *possible* ADR needs (hard-to-reverse,
   surprising, a real trade-off) — flag, don't create.

## Filing

Write the `audit-findings` artifact per `~/Dev/notes/_saving.md` — read it. Record
prototype source + reliable baseline in frontmatter, reuse the increment `id`,
`[[link]]` the aar. If the increment isn't ready for `spec`, say so plainly with
the reason. Close by updating `HEAD.md`.
