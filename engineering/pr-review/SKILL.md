---
name: pr-review
description: >-
  Review a GitHub pull request — compose the `review` discipline against a PR's
  diff for correctness bugs and cleanups. Qualifies to dodge the built-in
  /review. Use on "review PR #123", "review this pull request".
disable-model-invocation: true
model: claude-opus-5
effort: high
---

# pr-review

A thin front door: point the `review` discipline at a GitHub PR.

1. **Fetch the PR** — resolve the PR ref from the user; pull its diff, title,
   and description via `gh` (git mechanics via @tux if needed). State the base.
2. **Compose `review`** — run the `review` discipline on the PR diff at Opus 5
   high, reading surrounding code to ground findings.
3. **Return findings** — most-severe first. Post as inline PR comments only on
   explicit request (that publishes) — otherwise return them in-chat.

No artifact — the findings are the deliverable.
