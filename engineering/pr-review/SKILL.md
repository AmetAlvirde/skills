---
name: pr-review
description: >-
  Review a GitHub pull request by composing the `review` discipline against a
  PR's diff for correctness bugs and cleanups. Qualifies to dodge the built-in
  /review. Use on "review PR #123", "review this pull request".
model: claude-opus-5-5
effort: high
---

# pr-review

A thin front door: point the `review` discipline at a GitHub PR.

1. **Fetch the PR.** Resolve the PR ref from the user; pull its diff, title,
   and description via `gh` (git mechanics via @tux if needed). State the base.
2. **Compose `review`.** Run the `review` discipline on the PR diff at this
   invocation's configured tier, reading surrounding code to ground findings.
3. **Return findings**, most-severe first. Post as inline PR comments only on
   explicit request, since that publishes; otherwise return them in-chat.
4. **Request one retry only when blocked.** If an important candidate remains
   unverified, return `Retry recommended: <reason>` and point to
   `/pr-review-retry <reason>`. That command starts a fresh xhigh turn; it is not
   an in-flight tier change. Do not recommend it merely for wider coverage or
   after an already retried pass.

No artifact. The findings are the deliverable.
