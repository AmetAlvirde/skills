# skills — architecture & router

This repo is the single source of truth for a layered, tool-agnostic skill set.
Every skill is a directory with a `SKILL.md`; agents are single markdown files.
The invariants below are load-bearing — read them before adding or editing
anything.

## Layers

- **`global/`** — primitives that apply everywhere, symlinked into
  `~/.claude/skills/`: `map`, `grill`, `handoff`, `writing-great-skills`,
  `register-project`.
- **`engineering/`** — the dev-flow composition layer, **project-scoped**:
  per-skill symlinked into a real `<repo>/.claude/skills/` only for repos that
  opt in, by `register-project`. The bucket is atomic — an engineering
  orchestrator and any discipline it composes scope together.
- **`agents/`** — personas symlinked into `~/.claude/agents/` (global tier):
  `@ennio` (orchestrate, Opus 4.8 xhigh) · `@bit` (implement/refactor, Sonnet
  4.6) · `@tux` (git, Haiku/Sonnet) · `@linn` (docs, Sonnet 4.6).

## Invocation taxonomy

Every **engineering** skill is one of two kinds:

- **Orchestrator** — a thin front door a human runs. `disable-model-invocation:
  true` (zero per-turn cost until invoked). Composes disciplines by prose.
- **Discipline** — the reusable method, `user-invocable: false` (model-only,
  hidden from `/`). Rich trigger description.

**The one rule:** an orchestrator composes disciplines, **never** another
orchestrator. Shared behavior lives once, in a discipline.

The `global/` primitives (`map`/`grill`/`handoff`/`writing-great-skills`) are a
deliberate exception: they stay **model-invoked front doors** so they trigger on
natural language ("grill this", "map it out"). They are the shared disciplines
the engineering orchestrators compose.

## Naming

`<qualifier>-<primitive>`. The bare primitive is the general case; a qualifier
specializes it (`grill` → `codebase-grill`; `review` → `codebase-review`,
`pr-review`). Qualify to dodge built-ins (`/code-review`, `/review`).

## Tiering

Single-turn disciplines pin `model`/`effort` in **skill** frontmatter (resets
next turn — correct for one-shot methods). Multi-turn/agentic work tiers via the
**agent**, which holds the tier across the loop. Ceiling: Opus 4.8 xhigh (Fable
while the subscription allows). **Sonnet 4.6 is preferred over Sonnet 5** — pin
the full id `claude-sonnet-4-6`, never the `sonnet` alias (which resolves to
Sonnet 5).

## Router — MUST NOT LIE

The table below is the dispatch map of every user-reachable skill. **When you
add, rename, remove, or re-scope a skill, update this table in the same commit.**
A router that lies is the named failure mode of this repo.

| Skill | Layer | Kind | What it does |
|---|---|---|---|
| `map` | global | model-invoked | Diverge a raw idea into the territory to consider. |
| `grill` | global | model-invoked | Converge one branch to shared understanding, one question at a time. |
| `handoff` | global | model-invoked | Capture working state for a zero-context successor. |
| `writing-great-skills` | global | model-invoked | Author/prune skills (taxonomy, naming, failure modes). |
| `register-project` | global | user-invoked | Wire a repo to consume `engineering/` skills; scaffold its vault HEAD. |
| `codebase-grill` | engineering | orchestrator | Load repo context, then compose `grill` against the live code. |
| `spec` | engineering | orchestrator | Synthesize a spec from an agreed understanding; publish + file. |

## Vault

Skills are stateless. They persist artifacts to `~/Dev/notes` per that vault's
`_saving.md` (path, frontmatter, HEAD update, wikilinks) — the single filing
spec, never duplicated into a skill. `cycle` and `SDP` are retired vocabulary;
do not emit them.

## Deferred (not yet built)

- Extracting a standalone model-invoked grill discipline and splitting the global
  `grill` primitive into orchestrator + discipline. For now `codebase-grill`
  composes the existing `grill` directly — same thesis, no duplication, without
  destabilizing a ratified primitive. Decide with Amet before splitting.
- The rest of the `engineering/` suite (prototype, refactor, audit, issues,
  implement, aar, adr, update-docs, codebase-review, pr-review) per the map.
