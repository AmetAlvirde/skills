---
name: converge
description: >-
  The convergence method — walk a logic tree of dependent decisions, resolving
  one numbered question at a time with a recommended answer, until user and
  agent share understanding; then file the grill artifact. Model-invoked
  discipline composed by `grill`, `codebase-grill`, and other specialized
  grills; not run directly.
user-invocable: false
---

# converge

Scrutinize a subject until you and the user would describe it the same way, with
no load-bearing decision left fuzzy. Interactive, **one question at a time**.

The invoking front door sets the subject, the tier, and the **lens** — what a
weak joint looks like in that domain, and what it may resolve for itself rather
than ask. Absent a lens, treat every load-bearing decision as the user's.

1. **Scope** what's being grilled — a map node, a decision, an idea. Given a
   whole map, start at the most upstream / uncertain branch.
2. **Build the logic tree** — enumerate the dependent decisions, order them
   topologically (what others hinge on goes first), and show the user the path.
3. **Ask one numbered question** for the current node:

   > **Q\<n>. \<question>** _Blocks:_ \<one line on why it matters>
   > **Recommendation:** \<your answer> — \<reasoning; name what would flip it>

   One open question at a time; number continuously (Q1, Q2…) across the
   session.

4. **Record & propagate** — restate the locked decision in a line, then
   re-derive which downstream nodes it closes, opens, or changes. Update the
   tree; next Q.
5. **Walk every branch** to a locked decision or an explicitly parked question —
   no silent gaps.
6. **Exit on shared understanding** — summarize the resolved tree, confirm.

Push back honestly; the job is to find weak joints, not ratify the first idea.
Write the artifact after convergence: subject, decisions locked (numbered +
rationale), parked questions, what it feeds.

A good convergence session is never longer than 50 questions.

## Filing

Save per `~/Dev/notes/_saving.md` — **read it**; source of truth for path,
frontmatter, HEAD update, and wikilinks. This one: `artifact: grill`, file
`<project>/<YYYY-MM-DD>-<topic>-grill.md`, `repo`/`repo_path` from cwd; reuse
the source map's `id` and `[[link]]` it, and match existing grills' style in the
project folder. Close by updating `<project>/HEAD.md` and offering to commit. If
a decision rationale here would repeat on another project, run the valve
(`_conventions.md` §4).
