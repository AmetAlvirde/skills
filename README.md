# skills

Personal, tool-agnostic agent skills — the single source of truth. Layered:
`global/` primitives everywhere, `engineering/` dev-flow skills per-repo, and
`agents/` personas. See [`CLAUDE.md`](./CLAUDE.md) for the architecture, the
invocation taxonomy, and the router invariant.

## Layout

- **`global/`** — `map`, `grill`, `handoff`, `writing-great-skills`,
  `register-project`. Symlinked into `~/.claude/skills/`; apply in every repo.
- **`engineering/`** — the dev-flow composition layer (`codebase-grill`, `spec`,
  … more per the map). **Project-scoped**: linked into a repo only when it opts
  in via `register-project`.
- **`agents/`** — personas (`@ennio`, `@bit`, `@tux`, `@linn`). Symlinked into
  `~/.claude/agents/`.

`map` and `grill` are complements (diverge / converge); `writing-great-skills`
governs how every skill here is authored. All three write markdown artifacts into
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

`register-project` creates and maintains these links. To (re)link the globals and
agents by hand (idempotent):

```sh
for s in "$HOME"/Dev/skills/global/*/; do
  ln -sfn "$s" "$HOME/.claude/skills/$(basename "$s")"
done
for a in "$HOME"/Dev/skills/agents/*.md; do
  ln -sfn "$a" "$HOME/.claude/agents/$(basename "$a")"
done
```

To wire a repo to the `engineering/` skills, run `register-project` from that
repo's root — it creates per-skill symlinks into `<repo>/.claude/skills/` and
gitignores them.

Editing a `SKILL.md` here updates the skill everywhere immediately — no copy step.
