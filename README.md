# skills

Personal, tool-agnostic agent skills — the single source of truth. Layered:
`global/` primitives everywhere, `engineering/` dev-flow skills per-repo, and
`agents/` personas. [`CLAUDE.md`](./CLAUDE.md) holds the load-bearing
**invariants** (always loaded when this repo is cwd); the fuller architecture,
tiering, and the **router table** live below (read on demand).

## Layout

- **`global/`** — `map`, `grill`, `handoff`, `skill-setup`,
  `project-setup`, `standup`, `hotwash`. Symlinked into `~/.claude/skills/`;
  apply in every repo.
- **`engineering/`** — the dev-flow composition layer (`codebase-grill`, `spec`,
  … more per the map). **Project-scoped**: linked into a repo only when it opts
  in via `project-setup`.
- **`agents/`** — personas (`@ennio`, `@bit`, `@tux`, `@linn`, `@radar`).
  Symlinked into `~/.claude/agents/`.

`map` and `grill` are complements (diverge / converge); `skill-setup`
governs how every skill here is authored. All three write markdown artifacts
into `~/Dev/notes` following that vault's `_saving.md`.

## How they're wired

Skills reach the tool via **direct, gitignored symlinks** — one hop, no
intermediate `~/.agents/skills` staging directory.

```
~/Dev/skills/global/<skill>/SKILL.md   ← source (this repo)
  ↑ symlink
~/.claude/skills/<skill>               ← where Claude Code discovers it (everywhere)

~/Dev/skills/engineering/<skill>       ← source (this repo)
  ↑ symlink (per-skill, opt-in per repo)
<repo>/.claude/skills/<skill>          ← discovered only when that repo is cwd

~/Dev/skills/agents/<agent>.md         ← source (this repo)
  ↑ symlink
~/.claude/agents/<agent>.md            ← persona, available everywhere
```

`project-setup` creates and maintains these links. To (re)link the globals
and agents by hand (idempotent):

```sh
for s in "$HOME"/Dev/skills/global/*/; do
  ln -sfn "$s" "$HOME/.claude/skills/$(basename "$s")"
done
for a in "$HOME"/Dev/skills/agents/*.md; do
  ln -sfn "$a" "$HOME/.claude/agents/$(basename "$a")"
done
```

To wire a repo to the `engineering/` skills, run `project-setup` from that
repo's root — it creates per-skill symlinks into `<repo>/.claude/skills/` and
gitignores them.

Editing a `SKILL.md` here updates the skill everywhere immediately — no copy
step.

## Invocation taxonomy

Every **engineering** skill is one of two kinds:

- **Orchestrator** — a thin front door a human runs. `disable-model-invocation:
  true` (zero per-turn cost until invoked). Composes disciplines by prose.
- **Discipline** — the reusable method, `user-invocable: false` (model-only,
  hidden from `/`). Rich trigger description.

The one rule (an invariant — see `CLAUDE.md`): an orchestrator composes
disciplines, **never** another orchestrator. Shared behavior lives once, in a
discipline.

The `global/` primitives (`map`/`grill`/`handoff`/`skill-setup`) are a
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
high while the subscription allows). **Sonnet 4.6 is preferred over Sonnet 5** —
pin the full id `claude-sonnet-4-6`, never the `sonnet` alias (which resolves to
Sonnet 5).

Agent tiers (default → escalation when a turn is genuinely stuck):

| Agent    | Role                | Default          | Escalation      |
| -------- | ------------------- | ---------------- | --------------- |
| `@ennio` | orchestrate         | Opus 4.8 high    | Opus 4.8 xhigh  |
| `@bit`   | implement/refactor  | Opus 4.8 medium  | Opus 4.8 high   |
| `@tux`   | git                 | Haiku 4.5        | Sonnet 4.6 med  |
| `@linn`  | docs / vault        | Sonnet 4.6 med   | Opus 4.8 high   |
| `@radar` | state / briefings   | Opus 4.8 medium  | Opus 4.8 high   |

Single-turn skills self-tier: `codebase-grill` = Opus 4.8 high; `spec` = Opus
4.8 high (→ xhigh when the synthesis fights back).

## Router

The dispatch map of every user-reachable skill. **Invariant (see `CLAUDE.md`):
when you add, rename, remove, or re-scope a skill, update this table in the same
commit.** A router that lies is the named failure mode of this repo.

| Skill                  | Layer       | Kind          | What it does                                                           |
| ---------------------- | ----------- | ------------- | --------------------------------------------------------------------- |
| `map`                  | global      | model-invoked | Diverge a raw idea into the territory to consider.                     |
| `grill`                | global      | model-invoked | Converge one branch to shared understanding, one question at a time.   |
| `handoff`              | global      | model-invoked | Capture working state for a zero-context successor.                    |
| `skill-setup`          | global      | model-invoked | Author/prune skills (taxonomy, naming, failure modes).                 |
| `project-setup`        | global      | user-invoked  | Wire a repo to consume `engineering/` skills; scaffold its vault HEAD. |
| `standup`              | global      | user-invoked  | Log-in briefing: `@radar` refreshes `hq/SITREP.md`, opens the daylog.  |
| `hotwash`              | global      | user-invoked  | Log-out debrief: `@radar` seals the daylog, evidence-writes to HEADs.  |
| `codebase-grill`       | engineering | orchestrator  | Load repo context, then compose `grill` against the live code.         |
| `spec`                 | engineering | orchestrator  | Synthesize a spec from an agreed understanding; publish + file.        |

## Vault

Skills are stateless. They persist artifacts to `~/Dev/notes` per that vault's
`_saving.md` (path, frontmatter, HEAD update, wikilinks) — the single filing
spec, never duplicated into a skill. `cycle` and `SDP` are retired vocabulary;
do not emit them.

## Deferred (not yet built)

- Extracting a standalone model-invoked grill discipline and splitting the
  global `grill` primitive into orchestrator + discipline. For now
  `codebase-grill` composes the existing `grill` directly — same thesis, no
  duplication, without destabilizing a ratified primitive. Decide with Amet
  before splitting.
- The rest of the `engineering/` suite (prototype, refactor, audit, issues,
  implement, aar, adr, update-docs, codebase-review, pr-review) per the map.
