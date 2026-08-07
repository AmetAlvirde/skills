# skills

Personal, tool-agnostic agent skills — the single source of truth. Layered:
`global/` primitives everywhere, `engineering/` dev-flow skills per-repo, and
`agents/` personas. [`CLAUDE.md`](./CLAUDE.md) holds the load-bearing
**invariants** (always loaded when this repo is cwd); the fuller architecture,
tiering, and the **router table** live below (read on demand).

## Layout

- **`global/`** — `map`, `grill`, `diverge`, `converge`, `handoff`,
  `skill-setup`, `project-setup`, `standup`, `hotwash`. Symlinked into
  `~/.claude/skills/`; apply in every repo.
- **`engineering/`** — the dev-flow composition layer: the increment suite
  (`prototype`, `aar`, `audit`, `spec`, `issues`, `implement`, `refactor`, `adr`,
  `codebase-map`, `codebase-grill`, `codebase-review`, `pr-review`, `review`,
  `design`, `update-docs`).
  **Project-scoped**: linked into a repo only when it opts in via `project-setup`.
- **`agents/`** — personas (`@ennio`, `@bit`, `@tux`, `@linn`, `@radar`).
  Symlinked into `~/.claude/agents/`.

`map` and `grill` are complements — the general front doors to the `diverge` and
`converge` disciplines, which own the method and the artifact. `skill-setup`
governs how every skill here is authored. All write markdown artifacts into
`~/Dev/notes` following that vault's `_saving.md`.

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

- **Orchestrator** — a thin front door a human runs. Composes disciplines by
  prose. **Model-invocable by default** (the `*` rows in §Router — the roster is
  kept there, not duplicated here): a sub-agent reaches only skills the model may
  invoke, so guarding one hides the method from the very agent spawned to run it.
  Add `disable-model-invocation: true` only when the skill is **dialogue-bound** —
  it advances by asking the human numbered questions, so a sub-agent cannot run
  it to completion. The guard buys zero per-turn cost; a description is ~60–90
  tokens per turn, in wired repos only.
- **Discipline** — the reusable method, `user-invocable: false` (model-only,
  hidden from `/`). Rich trigger description.

The one rule (an invariant — see `CLAUDE.md`): an orchestrator composes
disciplines, **never** another orchestrator. Shared behavior lives once, in a
discipline.

The `global/` primitives (`map`/`grill`/`handoff`/`skill-setup`) are a
deliberate exception: they stay **model-invoked front doors** so they trigger on
natural language ("grill this", "map it out"). `map` and `grill` are the
*general* front doors, thin over the `diverge` / `converge` disciplines that any
specialized front door (`codebase-map`, `codebase-grill`, and future
`<domain>-grill|map`) composes directly.

A discipline lives at the lowest layer that covers all its consumers:
`converge`/`diverge` in `global/` because global front doors compose them;
`review` in `engineering/` because only engineering does.

Which name a bare family word takes: the **general user entry** when one exists
(`map`, `grill`), otherwise the **discipline** (`review` has no general front
door, so it keeps the bare name).

## Naming

`<qualifier>-<primitive>`. The bare primitive is the general case; a qualifier
specializes it (`grill` → `codebase-grill`; `review` → `codebase-review`,
`pr-review`). Qualify to dodge built-ins (`/code-review`, `/review`).

## Tiering

Single-turn disciplines pin `model`/`effort` in **skill** frontmatter (resets
next turn — correct for one-shot methods). Multi-turn/agentic work tiers via the
**agent**, which holds the tier across the loop. Ceiling: Opus 5 xhigh (Fable
high while the subscription allows). **Pin exact model ids** —
`claude-opus-5`, `claude-sonnet-5` — never a bare alias like `sonnet`, and
never append a date suffix.

Agent tiers (default → escalation when a turn is genuinely stuck):

| Agent    | Role                | Default        | Escalation    |
| -------- | ------------------- | -------------- | ------------- |
| `@ennio` | orchestrate         | Opus 5 high    | Opus 5 xhigh  |
| `@bit`   | implement/refactor  | Opus 5 medium  | Opus 5 high   |
| `@tux`   | git                 | Sonnet 5 med   | Opus 5 high   |
| `@linn`  | docs / vault        | Sonnet 5 med   | Opus 5 high   |
| `@radar` | state / briefings   | Opus 5 medium  | Opus 5 high   |

Single-turn skills self-tier: `codebase-map`, `codebase-grill`, `spec`, `refactor`,
`adr`, `issues`, `codebase-review`, `pr-review` = Opus 5 high (`spec` → xhigh
when the synthesis fights back); `audit` = Opus 5 xhigh; `aar` = Opus 5 medium. Multi-turn build skills
carry **no** skill pin — `prototype` and `implement` run as **@bit**,
`update-docs` as **@linn**; the `review` and `design` disciplines inherit the
tier of the skill that composes them.

Every agent **signs its tier**: each run closes with `— ran: <model-id> ·
effort: <tier>`, plus any bump above its default and why. The model id is
fact (the agent knows it); the effort is the agent's declared tier, not a
harness-verified readout — so the sign line surfaces an inherited-effort
mismatch (a sub-agent running above its pinned tier) instead of hiding it. An
agent that needs more than its ceiling flags it for a higher-tier re-spawn
rather than silently exceeding it.

## Commands

`commands/` holds one boot command per agent — a prompt template that makes the
main session **embody** that agent (you ARE it; not spawned as a sub-agent). Each
file symlinks to `~/.claude/commands/<name>.md` (wired once, like `agents/`), so
`/enn`, `/bit`, `/tux`, `/linn`, `/radar` resolve in any repo. `/enn` boots the
orchestrator / command-post companion — **bare** `/enn` orients across hq then
stands by; `/enn <task>` orients only at what the task names and explores lazily,
never reading hq to re-derive a scope it was handed. The other four boot a focused
single-worker session. `project-setup` links them alongside the agents.

## Router

The dispatch map of every user-reachable skill. **Invariant (see `CLAUDE.md`):
when you add, rename, remove, or re-scope a skill, update this table in the same
commit.** A router that lies is the named failure mode of this repo.

| Skill                  | Layer       | Kind          | What it does                                                           |
| ---------------------- | ----------- | ------------- | --------------------------------------------------------------------- |
| `map`                  | global      | model-invoked | General front door to divergence: compose `diverge` on a raw idea.     |
| `grill`                | global      | model-invoked | General front door to convergence: compose `converge` on a subject.    |
| `diverge`              | global      | discipline    | Shared divergence method + map artifact; composed, not run directly.   |
| `converge`             | global      | discipline    | Shared convergence method + grill artifact; composed, not run directly.|
| `handoff`              | global      | model-invoked | Capture working state for a zero-context successor.                    |
| `skill-setup`          | global      | model-invoked | Author/prune skills (taxonomy, naming, failure modes).                 |
| `project-setup`        | global      | user-invoked* | Wire a repo to consume `engineering/` skills; scaffold its vault HEAD. |
| `standup`              | global      | user-invoked  | Log-in briefing: `@radar` refreshes `hq/SITREP.md`, opens the daylog.  |
| `hotwash`              | global      | user-invoked  | Log-out debrief: `@radar` seals the daylog, evidence-writes to HEADs.  |
| `codebase-map`         | engineering | orchestrator  | Load repo context, then compose `diverge` with the code as the lens.   |
| `codebase-grill`       | engineering | orchestrator  | Load repo context, then compose `converge` against the live code.      |
| `prototype`            | engineering | orchestrator* | Build a throwaway prototype to learn; runs as @bit, files the note.    |
| `aar`                  | engineering | orchestrator* | Synthesize what the prototype taught — reliable vs discard.            |
| `audit`                | engineering | orchestrator* | Bucket the prototype→reliable assurance gap (analysis only).           |
| `spec`                 | engineering | orchestrator* | Synthesize a spec from an agreed understanding; publish + file.        |
| `issues`               | engineering | orchestrator* | Decompose an approved spec into tracer-bullet slice issues.            |
| `implement`            | engineering | orchestrator* | Build one reliable slice red→green; runs as @bit, commits via @tux.    |
| `refactor`             | engineering | orchestrator* | Diagnose a refactor → refactor-diagnosis; build via `implement`.       |
| `adr`                  | engineering | orchestrator* | Record a qualifying architecture decision in-repo; keep the index.     |
| `codebase-review`      | engineering | orchestrator* | Compose `review` against the local working diff.                       |
| `pr-review`            | engineering | orchestrator* | Compose `review` against a GitHub PR.                                  |
| `review`               | engineering | discipline    | Shared code-review method; composed by the two above, never direct.    |
| `design`               | engineering | discipline    | Design vocabulary (seam, depth, adapter) + smell baseline; composed.   |
| `update-docs`          | engineering | orchestrator* | Reconcile docs with the implementation; runs as @linn.                 |

`*` = also **model-invocable** (no `disable-model-invocation`), so a delegated
sub-agent can invoke it directly instead of only a human at the `/` prompt. The
unstarred `codebase-map` / `codebase-grill` / `standup` / `hotwash` stay
human-only because each advances by asking the human questions — see §Invocation
taxonomy.

Reach is scoped **per repo**, not by this flag: `engineering/` skills exist only
where `project-setup` symlinked them (`<repo>/.claude/skills/`), and that skill
asks which subset to link. A repo with no engineering skills linked — a writing
vault, say — never sees `codebase-map` in context whether it is guarded or not.

## Vault

Skills are stateless. They persist artifacts to `~/Dev/notes` per that vault's
`_saving.md` (path, frontmatter, HEAD update, wikilinks) — the single filing
spec, never duplicated into a skill. `cycle` and `SDP` are retired vocabulary;
do not emit them.

## Deferred (not yet built)

- Further specialized `<domain>-grill` / `<domain>-map` front doors (e.g. a
  `positions-grill` hunting cohesive market positioning). The seam is proven —
  `codebase-grill` and `codebase-map` are the first pair; each new one is
  `{preload context} + {domain lens} → compose converge|diverge`.
