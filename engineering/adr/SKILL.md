---
name: adr
description: >-
  Record an architecture decision that is hard to reverse, surprising without
  context, and a real trade-off — sparingly. Also loads and updates ADRs and the
  index. Use on "write an ADR", "record this decision", or when `refactor` /
  `audit` surfaces a qualifying decision.
model: claude-opus-5
effort: high
---

# adr

Most decisions do not qualify. Record one only when **all three** hold: hard to
reverse, surprising without context, the result of a real trade-off. Prototype
shortcuts, ordinary module extractions, and preferences without a trade-off do
not qualify.

Run it as **@vitruv** — an ADR is definition work, the same as `spec` and
`issues`: a record of what must be true, written for agents who will have none
of this context. The definer holds Opus 5 high, and what the tier buys here is
the three-test gate itself — whether the decision qualifies, and why. Declining
is a finished run. Git lands via @tux.

1. **Qualify or decline** — apply the three-test gate; if it fails, say so and
   don't write one. Qualifying shapes: architectural form, integration patterns,
   lock-in technology choices, context ownership, deliberate deviations, non-
   obvious rejected alternatives.
2. **Record minimally** — resolve the repo's ADR home through `HEAD.md`; read
   its index first, open only relevant ADRs. Write: short title, provenance,
   scope (product | context), status, and 1–3 sentences of context + decision +
   why. Add _Considered Options_ only for a rejected alternative worth
   remembering; _Consequences_ only for non-obvious downstream effects.
3. **Maintain the index** — add / supersede / deprecate the index row in the
   same edit. A superseded ADR points to its successor.

## Filing

ADRs are durable in-repo records — write them to the ADR home resolved through
`HEAD.md`, not the vault. Log a one-line `decisions-log` pointer in the vault
only if the increment tracks one. Git lands via @tux.
