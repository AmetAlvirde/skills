---
name: skill-setup
description: >-
  Author and prune agent skills so each one really communicates intent in the
  fewest tokens: invocation taxonomy, qualifier-first naming, leading words,
  tiering, and the named failure modes. Use when writing a new skill, editing an
  existing one, or reviewing a skill for bloat. Stateless: a discipline you run
  while editing, not an increment step.
---

# skill-setup

A skill is a lever on a model that already knows a lot. Write the smallest thing
that changes behavior in the direction you want; delete everything the model
would already do. Judge every line by: **does this change what the agent does
versus the default?** If not, cut it.

## 1. Invocation taxonomy: every skill is one of two kinds

- **Orchestrator** (user-invoked): a thin front door a human runs. Composes
  disciplines by prose ("Run the codebase-grill skill"). Target **≤ 15 lines**.
  Leave it **model-invocable by default**. A sub-agent reaches only skills the
  model may invoke, so guarding one hides the method from the agent spawned to
  run it. Add `disable-model-invocation: true` (description never injected
  per-turn, zero context until invoked) only when the skill is **dialogue-bound**:
  it advances by asking the human numbered questions, so a sub-agent cannot run
  it to completion. A description costs ~60–90 tokens per turn; buy that back
  only for a skill nothing can delegate.
- **Discipline** (model-invoked): the reusable method, loaded on demand.
  Frontmatter `user-invocable: false` → hidden from the `/` menu, model-only.
  Rich, trigger-laden `description` (that's how the model finds it). Target
  **≤ 130 lines**.

The two flags are **opposites**, not synonyms. The bimodal size is the tell:
skills cluster short (front doors) or medium (methods), and a long orchestrator
or a chatty discipline is a smell.

**Exception: model-invoked front doors.** A few global primitives
(`map`/`grill`/`handoff`) are front doors that stay *model-invoked* so they
trigger on natural language ("grill this", "map it out") rather than an explicit
`/`. They set neither flag. Use this only for primitives whose whole value is
conversational triggering; every engineering skill takes one of the two kinds
above.

**The one rule:** an orchestrator may compose disciplines; it must **never**
compose another orchestrator. Shared behavior lives once, in a discipline; every
front door invokes it. This is the cure for structural duplication: composition
by prose, not copied boilerplate.

## 2. Naming: qualifier-first

`<qualifier>-<primitive>`. The **bare primitive is the general case**; a
qualifier prefix specializes it: `grill` → `codebase-grill`; `review` →
`codebase-review`, `pr-review`. The primitive carries the intent; the qualifier
narrows the target. Group siblings under a shared prefix (`codebase-*`). Dodge
collisions with built-ins (`/code-review`, `/review`) by qualifying.

## 3. Leading words

Anchor behavior in compact pretrained concepts: "tight loop", "red test",
"seam", "tracer bullet", "fog of war", "expand–contract". One good leading word
replaces a paragraph of explanation because the model already holds the concept.
This is the whole game of "communicating intent": borrow the model's priors
instead of re-teaching them.

## 4. Tiering: where the model choice lives

- **Single-turn disciplines** (grill, audit, adr, review): pin `model`/`effort`
  in **skill** frontmatter. The override is per-turn only; it resets on the
  next user prompt, which is exactly right for a one-shot method.
- **Multi-turn / agentic work** (implement, refactor, orchestration): tier via
  the **agent**, not the skill. A skill override can't hold a tier across a
  loop; an agent persona (e.g. @bit at Opus 5 medium) can.

Rule of thumb: if the work is one turn, tier it in the skill; if it spans turns,
tier it in the agent that owns it.

A skill cannot promote itself during that turn. When a fixed-tier pass can end
in a specific, costly uncertainty, give it an explicit retry command backed by
`skillPins.<name>.retry`. The pass must state why; the command starts one fresh
turn at the retry target. A target without an entry point is dead configuration.

## 5. Progressive disclosure

Two costs, not one. **Context load** is tokens, what the model pays.
**Cognitive load** is what a human must hold to stay in the loop. That is the
price of human agency, and the one worth spending tokens to lower. A skill that
halves context load by making its output unreadable has spent the wrong
currency.

One folder per skill. `SKILL.md` holds what **every** path needs; push
branch-only material (templates, glossaries, long references) to sibling files
behind a context pointer ("see `templates.md`"). Inline templates are Sediment
waiting to happen; file them out.

The pointer's **wording is the reliability lever**. The model decides whether
to follow it from that sentence alone. "See `templates.md`" is a suggestion;
"read `templates.md`, it is the source of truth for X" is an instruction. Say
what the file settles, not that it exists.

## 6. Resolve through pointers, never hardcode

Skills are stateless and repo-agnostic. Resolve project/vault/repo through
`HEAD.md` frontmatter and `~/Dev/notes/_saving.md`; never hardcode a path,
tracker, or label. Point at the source of truth; don't copy it.

## 7. Failure modes: the pruning test

Run every skill (new or migrated) through these. Each is a reason to delete
lines, not add them:

- **Sediment**: stale layers that settle because adding feels safer than
  removing. The removable-line bloat in an old suite is Sediment in the wild.
- **No-op**: a line that doesn't change behavior versus the default ("be
  helpful", "use good judgment"). Costs context, buys nothing. Cut. The verdict
  is **model-relative**: a line that carried a weaker model can be dead weight on
  a stronger one, and only running the skill settles which. Don't argue it from
  the text.
- **Premature completion**: the agent stops while work remains, because the
  skill's bound was loose enough to look satisfied. A **completion criterion**
  has two axes. *Clarity*, how unambiguously "done" is testable, resists
  premature completion. *Demand*, how much the criterion asks for, drives
  legwork. Defend in that order: first restate "done" as an end state the agent
  can observe (a file that exists, a command that exits 0, a line that got
  printed), never an adjective; only if that fails, hide the post-completion
  steps behind a pointer the agent must go fetch.
- **Duplication**: the same protocol in N skills. Extract to one discipline;
  compose it.
- **Sprawl**: a skill doing several jobs. Split by turn-lifetime and by
  primitive.
- **Negation**: prohibitions make the forbidden behavior *more* available.
  State the positive ("commit via @tux"), not the negative ("don't commit
  yourself").
- **Negative Space**: what you leave unsaid delegates to model priors. Say the
  load-bearing thing even if it feels obvious; stay silent only where the prior
  is genuinely what you want.

The worked example: deleting a whole "workflow" section because the model
already knows the workflow. If cutting a section doesn't change behavior, the
section was No-op.

## 8. Filing

None. This skill writes no artifact. It is a discipline you run while editing a
SKILL.md, and it governs how every skill in this repo is authored and pruned.
When a skill changes name, splits, or is absorbed, re-sync the router
(`README.md` §Router) in the same edit. A router that lies is the named repo
failure.
