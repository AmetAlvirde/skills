# skills: invariants

This repo is the single source of truth for a layered, tool-agnostic skill set:
`global/` primitives (symlinked everywhere), `engineering/` disciplines
(project-scoped, opt-in), `agents/` personas. Every skill is a directory with a
`SKILL.md`; agents are single portable markdown prompts rendered with native
harness metadata at install time.

Only the **load-bearing invariants** live here. This file is auto-loaded every
turn while the repo is cwd, so it stays small. The full architecture, invocation
taxonomy, tiering matrix, and the **router table** live in
[`README.md`](./README.md) (read on demand). Read it before adding or editing a
skill.

## Invariants

- **Composition, the one rule.** An orchestrator composes disciplines, **never**
  another orchestrator. Shared behavior lives once, in a discipline; every front
  door invokes it.
- **Naming.** `<qualifier>-<primitive>`. The bare primitive is the general case;
  a qualifier specializes it (`grill` → `codebase-grill`). Qualify to dodge
  built-ins (`/code-review`, `/review`).
- **Tiering ceiling.** Opus 5 xhigh is the Claude ceiling (Fable high while the
  subscription allows). Claude-native skill frontmatter and rendered agent
  frontmatter pin exact model ids: `claude-opus-5`, `claude-sonnet-5`. Never a
  bare alias, never a date suffix. Cross-harness targets live in
  `harness/models.json`; the per-agent / per-skill matrix is in
  [`README.md` §Tiering](./README.md#tiering).
- **Router MUST NOT LIE.** The dispatch map of every user-reachable skill lives
  in [`README.md` §Router](./README.md#router). When you add, rename, remove, or
  re-scope a skill, update that table **in the same commit**. A router that lies
  is the named failure mode of this repo.
- **Retired vocab.** Never emit `cycle` or `SDP`; both are retired. Skills are
  stateless; they persist to `~/Dev/notes` per that vault's `_saving.md`, the
  single filing spec (never duplicated into a skill).
