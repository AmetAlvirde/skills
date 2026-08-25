---
name: project-setup
description: >-
  Wire a repo to consume the engineering skill set from ~/Dev/skills: create
  gitignored per-skill symlinks into the repo's real .claude/skills/, ensure the
  global primitives are linked, and scaffold the vault project. Use on "set up
  this project", "register this project", "wire up skills here", or when a repo
  should get the dev-flow skills. Idempotent.
---

# project-setup

Give a repo access to the `engineering/` skills without copying them. The
skill symlinks point back to `~/Dev/skills`; native persona files render from
the same canonical prompts. Idempotent: safe to re-run.

Run from the target repo's root (its path is cwd).

1. **Confirm the target**: the repo at cwd. Confirm which engineering skills to
   link; default to all of `~/Dev/skills/engineering/`. Ask before linking a
   subset.
2. **Run the manifest executor.** Run
   `~/Dev/skills/harness/wire --harness claude-code --project "$PWD" --apply`.
   For a subset, repeat `--skill <name>` on that command. It owns global links,
   rendered agents, commands, hooks, settings, the voice import, project links,
   and unmanaged-path reporting. Stop if it reports a warning; never replace an
   unmanaged path by hand.
3. **Gitignore the symlinks.** Ensure `<repo>/.gitignore` contains
   `.claude/skills/`. The symlinks are never committed; the source of truth is
   `~/Dev/skills`.
4. **Scaffold the vault project.** If `~/Dev/notes/<project>/HEAD.md` is missing,
   create the project folder and a `HEAD.md` per `~/Dev/notes/_saving.md` (read
   it; it is the source of truth for HEAD frontmatter and format), and register
   `<project>` in that file's project enum so the registry stays truthful. Match
   an existing project's `HEAD.md` in the vault.
5. **Report.** List what the executor linked or rendered, the gitignore change,
   the vault path, and every unmanaged path it flagged. Note any skills the repo
   already had.

## Filing

Writes no artifact of its own; step 4 scaffolds the vault project per
`_saving.md`. If registering surfaced a reusable wiring lesson, run the valve
(`_conventions.md` §4).
