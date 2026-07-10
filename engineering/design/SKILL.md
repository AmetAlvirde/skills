---
name: design
description: >-
  The software-design vocabulary — module, interface, depth, seam, adapter,
  leverage, locality — with the principles that bind it (the deletion test, the
  interface is the test surface, one adapter = hypothetical seam / two = real)
  and the code-smell baseline. Load whenever a skill or conversation names a
  seam, deep/shallow module, adapter, or blast radius, or when `review` /
  `audit` need the smell baseline. Vocabulary discipline: definitions to speak
  exactly, not steps to run.
user-invocable: false
---

# design

The single source of truth for design vocabulary. Consumers (`refactor`,
`spec`, `audit`, `implement`, `issues`, `codebase-map`, `review`) speak these
terms exactly — a run that improvises its own meaning of *seam* or *shallow*
drifts from every other run. Definitions state what a thing **is**; the
`_Avoid_` list names the synonyms to displace.

## Glossary

**Module** — a unit of code with an interface and an implementation; the unit
design judgments are about, at any scale (function, class, package, service).
_Avoid_: component, service, layer

**Interface** — everything a caller must know to use the module: entry points
and types, plus invariants, ordering, and error modes. The interface is the
test surface.
_Avoid_: API, surface area

**Implementation** — everything behind the interface. Free to change while
tests at the interface still pass; if a test must change too, it was testing
past the interface.

**Depth** — the leverage a module gives per interface entry point. A **deep**
module does a lot for its caller behind a small, simple interface; a
**shallow** one has an interface nearly as costly to learn as the
implementation it wraps. Judged by leverage, not by size (see Rejected
framings).
_Avoid_: abstraction level

**Seam** — a place where two modules meet and behavior can be observed or
substituted without reaching inside either. Tests live at seams; a seam is
**real** only when at least two adapters cross it, otherwise it is
hypothetical indirection.
_Avoid_: boundary, edge

**Adapter** — one swappable implementation crossing a seam (an HTTP adapter in
production, an in-memory adapter in tests). Counting adapters is how a seam is
priced: one is hypothetical, two make it real.
_Avoid_: wrapper, shim

**Leverage** — how much work a module does for its caller per unit of
interface learned. The currency depth is measured in.

**Locality** — how tightly a change concentrates. High locality: one module
absorbs it. Low locality: the same logical change forces edits scattered
across the codebase (its **blast radius**).
_Avoid_: cohesion, coupling (name the locality outcome instead)

## Principles

- **The deletion test.** Suspect a module is shallow? Ask: would deleting it
  and merging its work into its caller *concentrate* complexity into a deeper
  module, or just relocate it? "Concentrates" is the signal to deepen.
- **The interface is the test surface.** Tests assert observable outcomes
  through the interface and survive internal refactors. Verifying through a
  side channel (querying the database instead of calling the interface) is
  testing past it.
- **One adapter = a hypothetical seam; two = a real one.** Don't introduce a
  port or indirection until a second adapter (usually the test one) justifies
  it.
- **Design it twice.** The first interface idea is rarely the best; when an
  interface matters, sketch a structurally different alternative before
  committing, and compare by depth, locality, and seam placement.

## Rejected framings

- **Depth as a lines ratio** (implementation lines ÷ interface lines) —
  rejected for **depth-as-leverage**. A large implementation behind a small
  interface can still do little *for the caller*; what the entry points do for
  their callers is the measure, not how much code hides behind them.
- **"Boundary"** — rejected for **seam**. A boundary only separates; a seam is
  where you can observe and substitute, which is what makes it useful for
  testing and deepening.

## Companions

- [deepening.md](deepening.md) — how to deepen a shallow cluster safely: the
  dependency taxonomy (which category ⇒ which test strategy), seam discipline,
  and replace-don't-layer testing. For `refactor` and `audit`.
- [smells.md](smells.md) — the twelve-smell baseline swept over a scope under
  review, with its binding rules. For `review` and `audit`.
