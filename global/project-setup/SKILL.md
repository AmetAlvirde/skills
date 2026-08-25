---
name: project-setup
description: >-
  Wire a repo to consume the engineering skill set from ~/Dev/skills through
  Claude Code, OpenCode, or both: create gitignored per-skill links through the
  manifest executor and scaffold the vault project. Use on "set up this
  project", "register this project", "wire up skills here", or when a repo
  should get the dev-flow skills. Idempotent.
---

# project-setup

Give a repo access to the `engineering/` skills without copying them. Skill
links point back to `~/Dev/skills`; native files render from the same canonical
sources. Idempotent: safe to re-run.

Run from the target repo's root (its path is cwd).

1. **Confirm the target and selection.** The target is the repo at cwd. Ask
   which active harnesses to wire: Claude Code, OpenCode, or both. Default to
   both unless the user narrows it. Confirm which engineering skills to link;
   default to all of `~/Dev/skills/engineering/` and ask before using a subset.
2. **Run the manifest executor once per selected harness.** For each harness,
   run `~/Dev/skills/harness/wire --harness <claude-code|opencode> --project
   "$PWD" --apply`. For a subset, repeat the identical `--skill <name>`
   selectors on every selected harness command. The executor owns global and
   project output plus unmanaged-path reporting. Stop immediately if any run
   reports a warning; leave every unmanaged path untouched.
3. **Gitignore selected skill directories only.** Ensure `<repo>/.gitignore`
   contains `.claude/skills/` when Claude Code was selected and
   `.opencode/skills/` when OpenCode was selected. Do not add the unselected
   harness directory. The links are never committed; the source of truth is
   `~/Dev/skills`.
4. **Scaffold the vault project.** If `~/Dev/notes/<project>/HEAD.md` is missing,
   create the project folder and a `HEAD.md` per `~/Dev/notes/_saving.md` (read
   it; it is the source of truth for HEAD frontmatter and format), and register
   `<project>` in that file's project enum so the registry stays truthful. Match
   an existing project's `HEAD.md` in the vault.
5. **Report.** List the selected harnesses, what the executor linked or
   rendered, the gitignore change, the vault path, and every unmanaged path it
   flagged. Note any skills the repo already had. Tell OpenCode users to quit
   and restart OpenCode so it discovers newly wired project skills.

## Filing

Writes no artifact of its own; step 4 scaffolds the vault project per
`_saving.md`. If registering surfaced a reusable wiring lesson, run the valve
(`_conventions.md` §4).
