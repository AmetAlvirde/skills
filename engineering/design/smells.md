# Smell baseline

A fixed set of code smells (Fowler, _Refactoring_ ch. 3) swept over the scope
under review — a diff for `review` / `pr-review`, modules or the whole
codebase for `audit`. The fixed set is the point: every run checks the same
twelve things by the same names, instead of improvising a smell vocabulary per
run.

## Binding rules

- **The repo overrides.** A standard the consuming repo documents (CLAUDE.md,
  contributing/standards docs, an ADR) always wins; where it endorses
  something the baseline would flag, suppress the smell.
- **Always a judgment call.** Report each hit as a labelled heuristic —
  "possible Feature Envy" — never a hard violation.
- **Skip what tooling enforces.** Linters and formatters already own their
  rules; flagging them is noise.

## The smells

Each entry reads *what it is* → *the fix*.

- **Mysterious Name** — a function, variable, or type whose name doesn't
  reveal what it does or holds. → Rename it; if no honest name comes, the
  design underneath is murky.
- **Duplicated Code** — the same logic shape in more than one place in the
  scope. → Extract the shared shape; call it from both.
- **Feature Envy** — a method reaching into another module's data more than
  its own. → Move the method onto the data it envies.
- **Data Clumps** — the same few fields or params always travelling together —
  a type wanting to be born. → Bundle them into one type; pass that.
- **Primitive Obsession** — a primitive or string standing in for a domain
  concept. → Give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type
  recurring across the scope. → Polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forcing scattered edits across many
  files (low locality). → Gather what changes together into one module.
- **Divergent Change** — one module edited for several unrelated reasons. →
  Split it so each module changes for one reason.
- **Speculative Generality** — abstraction, params, or hooks added for needs
  nothing has. → Delete it; inline until a real need shows. (A one-adapter
  seam is this smell in seam form.)
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't
  depend on. → Hide the walk behind one method on the first object.
- **Middle Man** — a module that mostly delegates onward. → Cut it; call the
  real target directly.
- **Refused Bequest** — a subclass or implementer ignoring or overriding most
  of what it inherits. → Drop the inheritance; compose instead.
