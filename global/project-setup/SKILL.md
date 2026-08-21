---
name: project-setup
description: >-
  Wire a repo to consume the engineering skill set from ~/Dev/skills — create
  gitignored per-skill symlinks into the repo's real .claude/skills/, ensure the
  global primitives are linked, and scaffold the vault project. Use on "set up
  this project", "register this project", "wire up skills here", or when a repo
  should get the dev-flow skills. Idempotent.
---

# project-setup

Give a repo access to the `engineering/` skills without copying them — symlinks
back to the single source of truth in `~/Dev/skills`. Idempotent: safe to re-run.

Run from the target repo's root (its path is cwd).

1. **Confirm the target** — the repo at cwd. Confirm which engineering skills to
   link; default to all of `~/Dev/skills/engineering/`. Ask before linking a
   subset.
2. **Link the globals once** (idempotent) — each `~/Dev/skills/global/<s>` →
   `~/.claude/skills/<s>`. Skip any that already resolve there. This is the whole
   `global/` tier (`map`, `grill`, `diverge`, `converge`, `handoff`,
   `skill-setup`, `project-setup`, `unslop`) plus agents:
   `~/Dev/skills/agents/<a>.md` → `~/.claude/agents/<a>.md` and commands:
   `~/Dev/skills/commands/<c>.md` → `~/.claude/commands/<c>.md`. Also ensure
   `~/.claude/CLAUDE.md` carries the voice-contract import (append
   `@~/Dev/skills/global/unslop/VOICE.md` if absent) — an `@` import, not a
   symlink, and the only always-loaded file in the set.
3. **Link the engineering skills per-skill** into a **real** dir — create
   `<repo>/.claude/skills/` if absent, then for each chosen skill
   `ln -sfn ~/Dev/skills/engineering/<s> <repo>/.claude/skills/<s>`. Per-skill,
   not a whole-dir link: promoting one skill to `global/` later stays a
   deliberate move.
4. **Flag unmanaged dirs** — after linking, list anything in
   `<repo>/.claude/skills/` that is a **real directory, not a symlink into
   `~/Dev/skills`** (e.g. vendored or retired skill sets). Report each as
   `unmanaged — review/remove`; never delete it — removal is a deliberate act for
   the operator, not a side effect of setup.
5. **Gitignore the symlinks** — ensure `<repo>/.gitignore` contains
   `.claude/skills/`. The symlinks are never committed; the source of truth is
   `~/Dev/skills`.
6. **Scaffold the vault project** — if `~/Dev/notes/<project>/HEAD.md` is missing,
   create the project folder and a `HEAD.md` per `~/Dev/notes/_saving.md` (read
   it — it is the source of truth for HEAD frontmatter and format), and register
   `<project>` in that file's project enum so the registry stays truthful. Match
   an existing project's `HEAD.md` in the vault.
7. **Report** — list what was linked (globals, agents, per-repo skills), the
   gitignore change, the vault path, and any **unmanaged dirs flagged** in step 4.
   Note any skills the repo already had.

## Filing

Writes no artifact of its own; step 5 scaffolds the vault project per
`_saving.md`. If registering surfaced a reusable wiring lesson, run the valve
(`_conventions.md` §4).
