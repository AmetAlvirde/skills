# skills

Personal, tool-agnostic agent skills — the source of truth. Each skill is a
directory with a `SKILL.md` (YAML frontmatter + instructions).

## Skills

- **handoff** — close a context window into a handoff artifact so a fresh agent
  resumes with zero prior context.
- **map** — turn a raw idea into a structured map of everything to consider
  (branches, decisions, dependencies, unknowns) before planning. Breadth pass.
- **grill** — scrutinize an idea or one branch of a map until shared
  understanding, resolving decision dependencies one numbered question at a time,
  each with a recommendation. Depth / convergence pass.

`map` and `grill` are complements: map lays out the branches; grill walks down one
and converges. All three write markdown artifacts into `~/Dev/notes` following that
vault's `_conventions.md`.

## How they're wired

This repo is the source of truth. Skills are exposed to tools via a two-hop
symlink chain:

```
~/Dev/skills/<skill>/SKILL.md     ← source (this repo)
  ↑ symlink
~/.agents/skills/<skill>          ← tool-agnostic location (shareable across tools)
  ↑ symlink
~/.claude/skills/<skill>          ← where Claude Code discovers them
```

To re-create the links (idempotent):

```sh
for s in handoff map grill; do
  ln -sfn "$HOME/Dev/skills/$s"        "$HOME/.agents/skills/$s"
  ln -sfn "../../.agents/skills/$s"    "$HOME/.claude/skills/$s"
done
```

Editing a `SKILL.md` here updates the skill everywhere immediately — no copy step.
