---
name: register-project
description: >-
  Wire a repo to consume the engineering skill set from ~/Dev/skills — create
  gitignored per-skill symlinks into the repo's real .claude/skills/, ensure the
  global primitives are linked, and scaffold the vault project. Use on "register
  this project", "wire up skills here", or when a repo should get the dev-flow
  skills. Idempotent.
---

# register-project

Give a repo access to the `engineering/` skills without copying them — symlinks
back to the single source of truth in `~/Dev/skills`. Idempotent: safe to re-run.

Run from the target repo's root (its path is cwd).

1. **Confirm the target** — the repo at cwd. Confirm which engineering skills to
   link; default to all of `~/Dev/skills/engineering/`. Ask before linking a
   subset.
2. **Link the globals once** (idempotent) — each `~/Dev/skills/global/<s>` →
   `~/.claude/skills/<s>`. Skip any that already resolve there. This is the whole
   `global/` tier (`map`, `grill`, `handoff`, `writing-great-skills`,
   `register-project`) plus agents: `~/Dev/skills/agents/<a>.md` →
   `~/.claude/agents/<a>.md`.
3. **Link the engineering skills per-skill** into a **real** dir — create
   `<repo>/.claude/skills/` if absent, then for each chosen skill
   `ln -sfn ~/Dev/skills/engineering/<s> <repo>/.claude/skills/<s>`. Per-skill,
   not a whole-dir link: promoting one skill to `global/` later stays a
   deliberate move.
4. **Gitignore the symlinks** — ensure `<repo>/.gitignore` contains
   `.claude/skills/`. The symlinks are never committed; the source of truth is
   `~/Dev/skills`.
5. **Scaffold the vault project** — if `~/Dev/notes/<project>/HEAD.md` is missing,
   create the project folder and a `HEAD.md` per `~/Dev/notes/_saving.md` (read
   it — it is the source of truth for HEAD frontmatter and format). Match an
   existing project's `HEAD.md` in the vault.
6. **Report** — list what was linked (globals, agents, per-repo skills), the
   gitignore change, and the vault path. Note any skills the repo already had.

## Filing

Writes no artifact of its own; step 5 scaffolds the vault project per
`_saving.md`. If registering surfaced a reusable wiring lesson, run the valve
(`_conventions.md` §4).
